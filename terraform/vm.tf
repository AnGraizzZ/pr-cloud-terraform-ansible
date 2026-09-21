resource "yandex_compute_instance" "bastion"{
    platform_id = "standard-v2"
    name    = "bastion"    
    zone    = "ru-central1-d"
    boot_disk{
        initialize_params{
            image_id = "fd849rcpqs7mf5d38vg5"
            size = 10
        }
    }
    resources {
    cores         = 2
    core_fraction = 20
    memory        = 2
    }
    # scheduling_policy{
    #     preemptible = true
    # }
    network_interface {
    subnet_id = yandex_vpc_subnet.subnet_0_terraform_create.id
    security_group_ids = [yandex_vpc_security_group.bastion_sg.id]
    nat = true
    }
    # metadata = {
    #     ssh-keys = "agz:${file(var.ssh_path_pub)}"
    # }
    metadata = {
    user-data = templatefile("cloud-init.yml", {
      ssh_public_key = file(var.ssh_path_pub)
    serial-port-enable  = 1
    })
  }
}

resource "yandex_compute_instance" "webserver"{
    platform_id = "standard-v2"
    count   = 2
    name    = "webserver-${count.index}"    
    zone    = local.subnet_ids[count.index].zone
    boot_disk{
        initialize_params{
            image_id = "fd849rcpqs7mf5d38vg5"
            size = 10
        }
    }
    resources {
    cores         = 2
    core_fraction = 20
    memory        = 2
    }
    scheduling_policy{
        preemptible = true
    }
    network_interface {
    subnet_id = local.subnet_ids[count.index].id
    security_group_ids = [yandex_vpc_security_group.web_sg.id]
    nat       = false
    }
    metadata = {
    user-data = templatefile("cloud-init.yml", {
      ssh_public_key = file(var.ssh_path_pub)
    serial-port-enable  = 1
    })
  }
}



resource "yandex_compute_instance" "services_in"{
    platform_id = "standard-v2"
    name    = "prometheus-elasticsearch-services-in"    
    zone    = "ru-central1-d"
    boot_disk{
        initialize_params{
            image_id = "fd849rcpqs7mf5d38vg5"
            size = 10
        }
    }
    resources {
    cores         = 2
    core_fraction = 20
    memory        = 2
    }
    scheduling_policy{
        preemptible = true
    }
    network_interface {
    subnet_id = yandex_vpc_subnet.subnet_0_terraform_create.id
    security_group_ids = [yandex_vpc_security_group.in_sg.id]
    nat = false
    }
    metadata = {
    user-data = templatefile("cloud-init.yml", {
      ssh_public_key = file(var.ssh_path_pub)
    serial-port-enable  = 1
    })
  }
}

resource "yandex_compute_instance" "services_out"{
    platform_id = "standard-v2"
    name    = "grafana-kibana-services-out"    
    zone    = "ru-central1-d"
    boot_disk{
        initialize_params{
            image_id = "fd849rcpqs7mf5d38vg5"
            size = 10
        }
    }
    resources {
    cores         = 2
    core_fraction = 20
    memory        = 2
    }
    scheduling_policy{
        preemptible = true
    }
    network_interface {
    subnet_id = yandex_vpc_subnet.subnet_0_terraform_create.id
    security_group_ids = [yandex_vpc_security_group.out_sg.id]
    nat = true
    }
    metadata = {
    user-data = templatefile("cloud-init.yml", {
      ssh_public_key = file(var.ssh_path_pub)
    serial-port-enable  = 1
    })
  }
}

resource "local_file" "inventory" {
    content = <<-EOF
    [bastion]
    ${yandex_compute_instance.bastion.network_interface[0].nat_ip_address}

    [services_in]
    ${yandex_compute_instance.services_in.network_interface[0].ip_address}

    [services_out]
    ${yandex_compute_instance.services_out.network_interface[0].ip_address}
    
    [webservers]
    ${yandex_compute_instance.webserver[0].network_interface[0].ip_address}
    ${yandex_compute_instance.webserver[1].network_interface[0].ip_address}

    [grafana]
    ${yandex_compute_instance.services_out.network_interface[0].nat_ip_address}

    [all_services:children]
    services_in
    services_out
    webservers

    [all_services:vars]
    ansible_ssh_common_args='-o ProxyCommand="ssh -o StrictHostKeyChecking=no -W %h:%p -q agz@${yandex_compute_instance.bastion.network_interface[0].nat_ip_address}"'
    EOF
    filename             = "../ansible/hosts.ini"
}