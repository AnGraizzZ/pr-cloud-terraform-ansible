#группа vm которые будут использоваться балансировщиком
resource "yandex_alb_target_group" "group_vm_target" {
  name  = "group-vm-target"

  dynamic "target"{
    for_each = yandex_compute_instance.webserver
    content{
      subnet_id = target.value.network_interface[0].subnet_id
      ip_address   = target.value.network_interface[0].ip_address
    }
  }
}


//
// Create a new ALB Backend Group.
//
resource "yandex_alb_backend_group" "vm_backend_group" {
  name = "vm-backend-group"
  http_backend {
    name             = "http-backend"
    weight           = 1
    port             = 80
    target_group_ids = ["${yandex_alb_target_group.group_vm_target.id}"]
   
    load_balancing_config {
      panic_threshold = 20
    }
    healthcheck {
      timeout  = "5s"
      interval = "10s"
      http_healthcheck {
        path = "/"
      }
    }
  }
}


resource "yandex_alb_http_router" "vm_http_router" {
  name = "vm-http-router"
}

resource "yandex_alb_virtual_host" "vm_virtual_host" {
  name           = "vm-virtual-host"
  http_router_id = yandex_alb_http_router.vm_http_router.id

  route {
    name = "root-route"

    http_route {
      http_match {
        path {
          prefix = "/"
        }
      }

      http_route_action {
        backend_group_id = yandex_alb_backend_group.vm_backend_group.id
      }
    }
  }
}


resource "yandex_alb_load_balancer" "my_alb" {
  name = "my-load-balancer"

  network_id = yandex_vpc_network.network_terraform_create.id
  security_group_ids = [yandex_vpc_security_group.alb_sg.id]
  allocation_policy {

    location {
    zone_id   = yandex_vpc_subnet.subnet_0_terraform_create.zone
    subnet_id = yandex_vpc_subnet.subnet_0_terraform_create.id
  }

    location {
    zone_id   = yandex_vpc_subnet.subnet_1_terraform_create.zone
    subnet_id = yandex_vpc_subnet.subnet_1_terraform_create.id
  }
  }

  listener {
    name = "my-listener"
    endpoint {
      address {
        external_ipv4_address {
        }
      }
      ports = [80]
    }
    http {
      handler {
        http_router_id = yandex_alb_http_router.vm_http_router.id
      }
    }
  }
}
