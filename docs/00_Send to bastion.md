```
---
- hosts: remote_server
  gather_facts: no
  vars_files:
    - variables.yml

  vars:
    path: "/Users/nagi"

  tasks:

  - name: check if file exists
    stat:
      path: /usr/bin/ansible
    register: file_status

  - name: apt update
    ansible.builtin.command: sudo apt update

  - name: apt install software-properties-common
    ansible.builtin.command: sudo apt install software-properties-common

  - name: apt-add-repository --yes --update ppa:ansible/ansible
    ansible.builtin.command: sudo apt-add-repository --yes --update ppa:ansible/ansible
    when: not file_status.stat.exists

  - name: install ansible
    become: true
    ansible.builtin.apt:
      name: ansible
      state: present
    when: not file_status.stat.exists

  - name: copy ssh_key_file to vm
    ansible.builtin.copy:
      src: "{{path}}/k8s_auto_project/ssh_key/terra-k8s-work"
      dest: ./
      mode: 0600

  - name: copy ssh_key_file to vm
    ansible.builtin.copy:
      src: "{{path}}/k8s_auto_project/ssh_key/terra-k8s-cont"
      dest: ./
      mode: 0600

  - name: create k8s file to bastion
    ansible.builtin.copy:
      src: "{{path}}/k8s_auto_project/ansible/bastion_ansible/c_main.yml"
      dest: ./
    
  - name: create controller file to bastion
    ansible.builtin.copy:
      src: "{{path}}/k8s_auto_project/ansible/bastion_ansible/controller.yaml"
      dest: ./

  - name: create worker file to bastion
    ansible.builtin.copy:
      src: "{{path}}/k8s_auto_project/ansible/bastion_ansible/worker.yaml"
      dest: ./

  - name: create c_main_last file to bastion
    ansible.builtin.copy:
      src: "{{path}}/k8s_auto_project/ansible/bastion_ansible/c_main_last.yml"
      dest: ./

  - name: copy encryption file to bastion
    ansible.builtin.copy:
      src: "{{path}}/k8s_auto_project/ansible/bastion_ansible/encryption-config.yaml"
      dest: ./

  - name: create k8s_variable_file to bastion
    ansible.builtin.copy:
      src: "{{path}}/k8s_auto_project/ansible/bastion_ansible/variables.yml"
      dest: ./

  - name: create k8s_init_file to bastion
    ansible.builtin.copy:
      src: "{{path}}/k8s_auto_project/ansible/bastion_ansible/remote_inventory.ini"
      dest: ./
      
  - name: create ansible.cfg to bastion
    ansible.builtin.copy:
      src: "{{path}}/k8s_auto_project/ansible/bastion_ansible/ansible.cfg"
      dest: ./
```
