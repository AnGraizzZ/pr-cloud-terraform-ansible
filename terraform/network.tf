#Создание облачной сети
resource "yandex_vpc_network" "network_terraform_create" {
  name = "network-${var.ntc}"
}

#Подсеть zone d
resource "yandex_vpc_subnet" "subnet_0_terraform_create" {
  name           = "subnet-0-${var.ntc}-ru-central1-d"
  v4_cidr_blocks = ["10.2.0.0/24"]
  zone           = "ru-central1-d"
  network_id     = yandex_vpc_network.network_terraform_create.id
  route_table_id = yandex_vpc_route_table.route_terraform_create.id
}

#Подсеть zone e
resource "yandex_vpc_subnet" "subnet_1_terraform_create" {
  name           = "subnet-1-${var.ntc}-ru-central1-e"
  v4_cidr_blocks = ["10.2.1.0/24"]
  zone           = "ru-central1-e"
  network_id     = yandex_vpc_network.network_terraform_create.id
  route_table_id = yandex_vpc_route_table.route_terraform_create.id
}

locals {
  subnet_ids = [
    yandex_vpc_subnet.subnet_0_terraform_create,
    yandex_vpc_subnet.subnet_1_terraform_create,
  ]
}


#NAT для выхода в интернет
resource "yandex_vpc_gateway" "nat_terraform_create" {
  name = "gateway-${var.ntc}"
  shared_egress_gateway {}
}

#Таблица маршрутизации
resource "yandex_vpc_route_table" "route_terraform_create" {
  name       = "route-${var.ntc}"
  network_id = yandex_vpc_network.network_terraform_create.id

  static_route {
    destination_prefix = "0.0.0.0/0"
    gateway_id         = yandex_vpc_gateway.nat_terraform_create.id
  }
}

# #открытие портов
resource "yandex_vpc_security_group" "bastion_sg" {
  name       = "bastion-sg-${var.ntc}"
  network_id = yandex_vpc_network.network_terraform_create.id

  ingress {
    description    = "Allow SSH from my IP only"
    protocol       = "TCP"
    port           = 22
    v4_cidr_blocks = ["0.0.0.0/0"] 
  }
  egress {
    description      = "Allow all outbound to internal network"
    protocol         = "ANY"
    v4_cidr_blocks   = ["10.2.0.0/16"] 
  }
}
resource "yandex_vpc_security_group" "web_sg" {
  name       = "web-sg-${var.ntc}"
  network_id = yandex_vpc_network.network_terraform_create.id

  # SSH только от бастиона 
  ingress {
    description        = "Allow SSH from bastion"
    protocol           = "TCP"
    port               = 22
    security_group_id  = yandex_vpc_security_group.bastion_sg.id 
  }

  
  # порты для подключения exporter
  ingress {
    description        = "Allow SSH from node_exporter"
    protocol           = "TCP"
    port               = 9100
    security_group_id  = yandex_vpc_security_group.in_sg.id 
  }  
  # порты для подключения exporter
  ingress {
    description        = "Allow SSH from nginx_exporter"
    protocol           = "TCP"
    port               = 8000
    security_group_id  = yandex_vpc_security_group.in_sg.id 
  }

  # ALB обращается к бэкендам по внутренним IP из этих подсетей
  ingress {
    description    = "Allow HTTP from ALB subnets"
    protocol       = "TCP"
    port           = 80
    v4_cidr_blocks = [
      yandex_vpc_subnet.subnet_0_terraform_create.v4_cidr_blocks[0],
      yandex_vpc_subnet.subnet_1_terraform_create.v4_cidr_blocks[0]
    ]
  }

  ingress {
    description    = "Allow HTTP from internet"
    protocol       = "TCP"
    port           = 80
    v4_cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description    = "Allow HTTPS from internet"
    protocol       = "TCP"
    port           = 443
    v4_cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    protocol       = "ANY"
    v4_cidr_blocks = ["0.0.0.0/0"]
  }
}
resource "yandex_vpc_security_group" "in_sg" {
  name       = "in-sg-${var.ntc}"
  network_id = yandex_vpc_network.network_terraform_create.id

  # SSH только от бастиона 
  ingress {
    description        = "Allow SSH from bastion only"
    protocol           = "TCP"
    port               = 22
    security_group_id  = yandex_vpc_security_group.bastion_sg.id
  }

  # Prometheus
  ingress {
    description      = "Allow Prometheus from internal network"
    protocol         = "TCP"
    port             = 9090
    v4_cidr_blocks   = ["0.0.0.0/0"] 
  }

  # Elasticsearch
  ingress {
    description      = "Allow Elasticsearch from internal network"
    protocol         = "TCP"
    port             = 9200
    v4_cidr_blocks   = ["10.2.0.0/16"]
  }
  
  # Elasticsearch
  ingress {
    description      = "Allow Elasticsearch from internal network"
    protocol         = "TCP"
    port             = 9300
    v4_cidr_blocks   = ["10.2.0.0/16"]
  }

  egress {
    description      = "Allow all outbound to internal and internet"
    protocol         = "ANY"
    v4_cidr_blocks   = ["0.0.0.0/0"]
  }
}
resource "yandex_vpc_security_group" "out_sg" {
  name       = "out-sg-${var.ntc}"
  network_id = yandex_vpc_network.network_terraform_create.id

  ingress {
  description       = "Allow SSH from bastion"
  protocol          = "TCP"
  port              = 22
  security_group_id = yandex_vpc_security_group.bastion_sg.id
  }
    # 3. Grafana
  ingress {
    description      = "Allow Grafana from internal network"
    protocol         = "TCP"
    port             = 3000
    v4_cidr_blocks   = ["0.0.0.0/0"]
  }

  # 4. Kibana
  ingress {
    description      = "Allow Kibana from internal network"
    protocol         = "TCP"
    port             = 5601
    v4_cidr_blocks   = ["0.0.0.0/0"]
  }

  egress {
    description      = "Allow all outbound to internal and internet"
    protocol         = "ANY"
    v4_cidr_blocks   = ["0.0.0.0/0"] 
  }
}
# 1. Создаем SG БАЛАНСИРОВЩИКА
resource "yandex_vpc_security_group" "alb_sg" {
  name       = "alb-sg-${var.ntc}"
  network_id = yandex_vpc_network.network_terraform_create.id


  ingress {
    description    = "Allow HTTP from internet to ALB"
    protocol       = "TCP"
    port           = 80
    v4_cidr_blocks = ["0.0.0.0/0"]
  }


  egress {
    description        = "Allow HTTP to web backends"
    protocol           = "TCP"
    port               = 80
    security_group_id  = yandex_vpc_security_group.web_sg.id
  }
}

