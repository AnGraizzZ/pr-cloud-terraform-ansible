
cd terraform 
  # terraform apply
cd ../ansible
    #  eval "$(ssh-agent -s)"
    #  ssh-add ~/.ssh/yc_key
  #  sleep 30
ansible-playbook -i hosts.ini site.yml --vault-password-file vault_pass.txt
