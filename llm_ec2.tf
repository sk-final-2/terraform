############ AMI: DLAMI (Ubuntu 22.04 + Nvidia Driver) - SSM에서 최신 AMI-ID 조회
data "aws_ssm_parameter" "dlami_ubuntu2204" {
  name = "/aws/service/deeplearning/ami/x86_64/base-oss-nvidia-driver-gpu-ubuntu-22.04/latest/ami-id"
}

############ IAM: SSM + ECR ReadOnly
data "aws_iam_policy_document" "assume_ec2" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "evaluate_role" {
  name               = "${var.name}-evaluate-role"
  assume_role_policy = data.aws_iam_policy_document.assume_ec2.json
}

resource "aws_iam_role_policy_attachment" "ssm_core" {
  role       = aws_iam_role.evaluate_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_role_policy_attachment" "ecr_ro" {
  role       = aws_iam_role.evaluate_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
}

resource "aws_iam_instance_profile" "evaluate_profile" {
  name = "${var.name}-evaluate-profile"
  role = aws_iam_role.evaluate_role.name
}

############ SG: backend(svc)에서만 8002 접근 허용
resource "aws_security_group" "evaluate_sg" {
  name   = "${var.name}-evaluate-sg"
  vpc_id = module.vpc.vpc_id

  ingress {
    description     = "backend services to evaluate 8002"
    from_port       = 8002
    to_port         = 8002
    protocol        = "tcp"
    security_groups = [aws_security_group.svc.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

############ EC2: 프라이빗 서브넷 + SSM 접속 + ECR pull/run(8002, GPU)
locals {
  evaluate_user_data = <<-BASH
    #!/bin/bash
    set -euo pipefail

    mkdir -p /var/lib/recruitai
    if [ -f /var/lib/recruitai/bootstrap-done ]; then
      systemctl daemon-reload || true
      systemctl enable --now evaluate-ai.service || true
      exit 0
    fi

    export DEBIAN_FRONTEND=noninteractive

    # 1) Docker CE 깔끔 설치 (충돌 패키지 제거)
    apt-get update -y
    apt-get purge -y docker.io docker-doc docker-compose docker-compose-plugin containerd || true
    install -m 0755 -d /etc/apt/keyrings
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
    echo "deb [arch=amd64 signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu jammy stable" > /etc/apt/sources.list.d/docker.list
    apt-get update -y
    apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
    systemctl enable --now docker
    usermod -aG docker ubuntu || true
    usermod -aG docker ssm-user || true

    # 2) NVIDIA Container Toolkit (repo 없을 때만 추가)
    if [ ! -f /etc/apt/sources.list.d/nvidia-container-toolkit.list ]; then
      curl -fsSL https://nvidia.github.io/libnvidia-container/gpgkey | gpg --dearmor -o /usr/share/keyrings/nvidia-container-toolkit-keyring.gpg
      distribution=$(. /etc/os-release;echo $ID$VERSION_ID)
      curl -fsSL https://nvidia.github.io/libnvidia-container/$distribution/libnvidia-container.list \
        | sed 's#deb https://#deb [signed-by=/usr/share/keyrings/nvidia-container-toolkit-keyring.gpg] https://#g' \
        > /etc/apt/sources.list.d/nvidia-container-toolkit.list
    fi
    apt-get update -y && apt-get install -y nvidia-container-toolkit
    nvidia-ctk runtime configure --runtime=docker

    # 도커 데몬 sane 기본(로그 롤링 + nvidia 런타임)
    cat >/etc/docker/daemon.json <<'JSON'
    {
      "default-runtime": "nvidia",
      "runtimes": { "nvidia": { "path": "nvidia-container-runtime", "runtimeArgs": [] } },
      "log-driver": "json-file",
      "log-opts": { "max-size": "10m", "max-file": "5" }
    }
    JSON
    systemctl restart docker

    # 3) systemd 유닛 (풀 지연 대비 TimeoutStartSec, 헬스체크, 환경변수 주입)
    cat >/etc/systemd/system/evaluate-ai.service <<'UNIT'
    [Unit]
    Description=Evaluate AI Container
    Wants=docker.service network-online.target
    After=docker.service network-online.target

    [Service]
    TimeoutStartSec=900
    Restart=always
    RestartSec=5
    Environment=IMAGE=${var.image_evaluate}
    ExecStartPre=/usr/bin/bash -lc "aws ecr get-login-password --region ${var.region} | docker login --username AWS --password-stdin ${element(split("/", var.image_evaluate), 0)}"
    ExecStartPre=/usr/bin/bash -lc "docker pull ${var.image_evaluate}"
    ExecStartPre=/usr/bin/bash -lc "docker rm -f evaluate-ai || true"
    ExecStart=/usr/bin/docker run --name evaluate-ai --pull=always --gpus all -p 8002:8002 \
      -e MODEL_PATH=/app/models/llama3-awq-quantized-model \
      -e VLLM_QUANT=awq \
      -e VLLM_MAX_MODEL_LEN=2048 \
      -e VLLM_MAX_BATCHED_TOKENS=2048 \
      -e SAMPLING_MAX_TOKENS=512\
      --health-cmd="curl -fsS http://localhost:8002/ || exit 1" \
      --health-interval=30s --health-retries=3 --health-timeout=5s \
      ${var.image_evaluate}
    ExecStop=/usr/bin/docker stop evaluate-ai

    [Install]
    WantedBy=multi-user.target
    UNIT

    systemctl daemon-reload
    systemctl enable --now evaluate-ai.service

    # 4) 부팅 완료 마커 + 1차 헬스
    sleep 8 || true
    curl -fsS http://localhost:8002/ || true
    touch /var/lib/recruitai/bootstrap-done
  BASH
}

resource "aws_instance" "evaluate" {
  ami                         = data.aws_ssm_parameter.dlami_ubuntu2204.value
  instance_type               = var.llm_instance_type # g4dn.xlarge
  subnet_id                   = module.vpc.private_subnets[0]
  vpc_security_group_ids      = [aws_security_group.evaluate_sg.id]
  associate_public_ip_address = false
  iam_instance_profile        = aws_iam_instance_profile.evaluate_profile.name
  key_name                    = null
  user_data                   = local.evaluate_user_data
  user_data_replace_on_change = true
  root_block_device {
    volume_size = var.llm_root_volume_size
    volume_type = "gp3"
    encrypted   = true
  }

  tags = {
    Name         = "${var.name}-evaluate"
    Role         = "evaluate-ai"
    ManagedBy    = "terraform"
    "cw:enabled" = "true"
  }
}

############ Cloud Map: evaluate-ai.<sd_namespace>
resource "aws_service_discovery_service" "sd_evaluate" {
  name = "evaluate-ai"

  dns_config {
    namespace_id   = aws_service_discovery_private_dns_namespace.ns.id
    routing_policy = "MULTIVALUE"

    dns_records {
      ttl  = 10
      type = "A"
    }
  }
}

resource "aws_service_discovery_instance" "evaluate" {
  service_id  = aws_service_discovery_service.sd_evaluate.id
  instance_id = aws_instance.evaluate.private_ip

  attributes = {
    AWS_INSTANCE_IPV4 = aws_instance.evaluate.private_ip
    AWS_INSTANCE_PORT = "8002"
  }
}

output "evaluate_private_ip" {
  value = aws_instance.evaluate.private_ip
}
