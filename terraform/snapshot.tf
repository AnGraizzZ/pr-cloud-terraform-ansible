resource "yandex_compute_snapshot_schedule" "daily_backup" {
  name        = "daily-vm-backup-schedule"
  description = "Ежедневный бэкап с удалением через 7 дней"

  # Расписание: ежедневно в 03:00
  schedule_policy {
    expression = "0 3 * * *"
  }

  # Срок хранения снимков: 7 дней
  retention_period = "604800s"

  disk_ids = [
        yandex_compute_instance.bastion.boot_disk[0].disk_id,
      yandex_compute_instance.services_in.boot_disk[0].disk_id,
      yandex_compute_instance.services_out.boot_disk[0].disk_id,
      yandex_compute_instance.webserver[0].boot_disk[0].disk_id,
      yandex_compute_instance.webserver[1].boot_disk[0].disk_id
 ]


}