# Create a file of commands to run on Bastion

```
---
- name: Run command in Azure Linux VM
  hosts: localhost
  gather_facts: no
  vars_files:
    - variables.yml

  tasks:
    - name: download cfssl
      ansible.builtin.get_url:
        dest: ./
        url: "https://storage.googleapis.com/kubernetes-the-hard-way/cfssl/1.4.1/linux/cfssl"
        backup: true

    - name: download cfssljson
      ansible.builtin.get_url:
        dest: ./
        url: "https://storage.googleapis.com/kubernetes-the-hard-way/cfssl/1.4.1/linux/cfssljson"
        backup: true

    - name: change authorization cfssljson
      ansible.builtin.command: chmod +x cfssl cfssljson

    - name: Move cfssl to /usr/local/bin/
      become: yes
      ansible.builtin.command: mv cfssl cfssljson /usr/local/bin/

    - name: download kubectl
      ansible.builtin.get_url:
        dest: ./
        url: https://storage.googleapis.com/kubernetes-release/release/v1.21.0/bin/linux/amd64/kubectl

    - name: Run a shell command
      ansible.builtin.command: chmod +x kubectl

    - name: Run a shell command
      ansible.builtin.command: mv kubectl /usr/local/bin/
      become: yes

    - name: Create ca-config.json
      ansible.builtin.copy:
        dest: ./ca-config.json
        content: |
          {
            "signing": {
              "default": {
                "expiry": "8760h"
              },
              "profiles": {
                "kubernetes": {
                  "usages": ["signing", "key encipherment", "server auth", "client auth"],
                  "expiry": "8760h"
                }
              }
            }
          }

    - name: Create ca-csr.json
      ansible.builtin.copy:
        dest: ./ca-csr.json
        content: |
          {
            "CN": "Kubernetes",
            "key": {
              "algo": "rsa",
              "size": 2048
            },
            "names": [
              {
                "C": "{{ region }}",
                "L": "Portland",
                "O": "Kubernetes",
                "OU": "CA",
                "ST": "{{ city }}"
              }
            ]
          }

    - name: create ca.pem ca-csr.json
      ansible.builtin.shell: cfssl gencert -initca ca-csr.json | cfssljson -bare ca

    - name: Create admin-csr.json
      ansible.builtin.copy:
        dest: ./admin-csr.json
        content: |
          {
            "CN": "admin",
            "key": {
              "algo": "rsa",
              "size": 2048
            },
            "names": [
              {
                "C": "{{ region }}",
                "L": "Portland",
                "O": "system:masters",
                "OU": "Kubernetes The Hard Way",
                "ST": "{{ city }}"
              }
            ]
          }
    
    - name: Run a shell command
      ansible.builtin.shell: cfssl gencert \
        -ca=ca.pem \
        -ca-key=ca-key.pem \
        -config=ca-config.json \
        -profile=kubernetes \
        admin-csr.json | cfssljson -bare admin

    - name: Create {{ worker_name }}-csr.json
      ansible.builtin.copy:
        dest: ./{{ worker_name }}-csr.json
        content: {
          "CN": "admin",
          "key": {
            "algo": "rsa",
            "size": 2048
          },
          "names": [
            {
              "C": "{{ region }}",
              "L": "Portland",
              "O": "system:masters",
              "OU": "Kubernetes The Hard Way",
              "ST": "{{ city }}"
            }
          ]
        }

    - name: Run a shell command kubelet-Cert
      ansible.builtin.shell: cfssl gencert \
        -ca=ca.pem \
        -ca-key=ca-key.pem \
        -config=ca-config.json \
        -hostname={{ worker_name }},{{ Worker_privateIP }} \
        -profile=kubernetes \
        {{ worker_name }}-csr.json | cfssljson -bare {{ worker_name }}

    - name: Create kube-controller-manager-csr.json
      ansible.builtin.copy:
        dest: ./kube-controller-manager-csr.json
        content: 
          {
            "CN": "system:kube-controller-manager",
            "key": {
              "algo": "rsa",
              "size": 2048
            },
            "names": [
              {
                "C": "{{ region }}",
                "L": "Portland",
                "O": "system:kube-controller-manager",
                "OU": "Kubernetes The Hard Way",
                "ST": "{{ city }}"
              }
            ]
          }

    - name: run a shell command
      ansible.builtin.shell: cfssl gencert \
        -ca=ca.pem \
        -ca-key=ca-key.pem \
        -config=ca-config.json \
        -profile=kubernetes \
        kube-controller-manager-csr.json | cfssljson -bare kube-controller-manager

    - name: Create kube-proxy-csr.json
      ansible.builtin.copy:
        dest: ./kube-proxy-csr.json
        content: |
          {
            "CN": "system:kube-proxy",
            "key": {
              "algo": "rsa",
              "size": 2048
            },
            "names": [
              {
                "C": "{{ region }}",
                "L": "Portland",
                "O": "system:node-proxier",
                "OU": "Kubernetes The Hard Way",
                "ST": "{{ city }}"
              }
            ]
          }

    - name: run a shell command
      ansible.builtin.shell: cfssl gencert \
        -ca=ca.pem \
        -ca-key=ca-key.pem \
        -config=ca-config.json \
        -profile=kubernetes \
        kube-proxy-csr.json | cfssljson -bare kube-proxy

    - name: Create kube-scheduler json file
      ansible.builtin.copy:
        dest: ./kube-scheduler-csr.json
        content: |
          {
            "CN": "system:kube-scheduler",
            "key": {
              "algo": "rsa",
              "size": 2048
            },
            "names": [
              {
                "C": "{{ region }}",
                "L": "Portland",
                "O": "system:kube-scheduler",
                "OU": "Kubernetes The Hard Way",
                "ST": "{{ city }}"
              }
            ]
          }

    - name: run a shell command
      ansible.builtin.shell: cfssl gencert \
        -ca=ca.pem \
        -ca-key=ca-key.pem \
        -config=ca-config.json \
        -profile=kubernetes \
        kube-scheduler-csr.json | cfssljson -bare kube-scheduler

    - name: Create kubernetes-csr.json
      ansible.builtin.copy:
        dest: ./kubernetes-csr.json
        content: 
          {
            "CN": "kubernetes",
            "key": {
              "algo": "rsa",
              "size": 2048
            },
            "names": [
              {
                "C": "{{ region }}",
                "L": "Portland",
                "O": "Kubernetes",
                "OU": "Kubernetes The Hard Way",
                "ST": "{{ city }}"
              }
            ]
          }

    - name: run a shell command
      ansible.builtin.shell: cfssl gencert \
        -ca=ca.pem \
        -ca-key=ca-key.pem \
        -config=ca-config.json \
        -hostname=10.32.0.1,{{ Controller_privateIP }},127.0.0.1,kubernetes,kubernetes.default,kubernetes.default.svc,kubernetes.default.svc.cluster,kubernetes.svc.cluster.local \
        -profile=kubernetes \
        kubernetes-csr.json | cfssljson -bare kubernetes

    - name: Create service-account-csr.json
      ansible.builtin.copy:
        dest: ./service-account-csr.json
        content: |
          {
            "CN": "service-accounts",
            "key": {
              "algo": "rsa",
              "size": 2048
            },
            "names": [
              {
                "C": "{{ region }}",
                "L": "Portland",
                "O": "Kubernetes",
                "OU": "Kubernetes The Hard Way",
                "ST": "{{ city }}"
              }
            ]
          }

    - name: run a shell command service-account
      ansible.builtin.shell: cfssl gencert \
        -ca=ca.pem \
        -ca-key=ca-key.pem \
        -config=ca-config.json \
        -profile=kubernetes \
        service-account-csr.json | cfssljson -bare service-account

    - name: Copy files from bastion to worker
      ansible.builtin.shell: scp -i ./{{ worker_name }} ./ca.pem {{ worker_name }}-key.pem {{ worker_name }}.pem {{ worker_name }}@{{ Worker_privateIP }}:~/

    - name: Copy files from bastion to controller
      ansible.builtin.shell: scp -i ./{{ cont_name }} ca.pem ca-key.pem kubernetes-key.pem kubernetes.pem service-account-key.pem service-account.pem {{ cont_name }}@{{ Controller_privateIP }}:~/

    - name: setting cluster in kube-conf
      ansible.builtin.shell: kubectl config set-cluster kubernetes-the-hard-way \
        --certificate-authority=ca.pem \
        --embed-certs=true \
        --server=https://{{ Controller_privateIP }}:6443 \
        --kubeconfig={{ worker_name }}.kubeconfig

    - name: setting credentials in kube-conf
      ansible.builtin.shell: kubectl config set-credentials system:node:{{ worker_name }} \
        --client-certificate={{ worker_name }}.pem \
        --client-key={{ worker_name }}-key.pem \
        --embed-certs=true \
        --kubeconfig={{ worker_name }}.kubeconfig

    - name: setting context in kube-conf
      ansible.builtin.shell: kubectl config set-context default \
        --cluster=kubernetes-the-hard-way \
        --user=system:node:{{ worker_name }} \
        --kubeconfig={{ worker_name }}.kubeconfig

    - name: setting use context default
      ansible.builtin.shell: kubectl config use-context default --kubeconfig={{ worker_name }}.kubeconfig

    - name: setting kube-proxy
      ansible.builtin.shell: |
        kubectl config set-cluster kubernetes-the-hard-way \
          --certificate-authority=ca.pem \
          --embed-certs=true \
          --server=https://{{ Controller_privateIP }}:6443 \
          --kubeconfig=kube-proxy.kubeconfig

        kubectl config set-credentials system:kube-proxy \
          --client-certificate=kube-proxy.pem \
          --client-key=kube-proxy-key.pem \
          --embed-certs=true \
          --kubeconfig=kube-proxy.kubeconfig

        kubectl config set-context default \
          --cluster=kubernetes-the-hard-way \
          --user=system:kube-proxy \
          --kubeconfig=kube-proxy.kubeconfig

        kubectl config use-context default --kubeconfig=kube-proxy.kubeconfig

    - name: setting kube-controller-manager
      ansible.builtin.shell: |
        kubectl config set-cluster kubernetes-the-hard-way \
          --certificate-authority=ca.pem \
          --embed-certs=true \
          --server=https://127.0.0.1:6443 \
          --kubeconfig=kube-controller-manager.kubeconfig

        kubectl config set-credentials system:kube-controller-manager \
          --client-certificate=kube-controller-manager.pem \
          --client-key=kube-controller-manager-key.pem \
          --embed-certs=true \
          --kubeconfig=kube-controller-manager.kubeconfig

        kubectl config set-context default \
          --cluster=kubernetes-the-hard-way \
          --user=system:kube-controller-manager \
          --kubeconfig=kube-controller-manager.kubeconfig

        kubectl config use-context default --kubeconfig=kube-controller-manager.kubeconfig

    - name: setting kube-scheduler
      ansible.builtin.shell: |
        kubectl config set-cluster kubernetes-the-hard-way \
          --certificate-authority=ca.pem \
          --embed-certs=true \
          --server=https://127.0.0.1:6443 \
          --kubeconfig=kube-scheduler.kubeconfig

        kubectl config set-credentials system:kube-scheduler \
          --client-certificate=kube-scheduler.pem \
          --client-key=kube-scheduler-key.pem \
          --embed-certs=true \
          --kubeconfig=kube-scheduler.kubeconfig

        kubectl config set-context default \
          --cluster=kubernetes-the-hard-way \
          --user=system:kube-scheduler \
          --kubeconfig=kube-scheduler.kubeconfig

        kubectl config use-context default --kubeconfig=kube-scheduler.kubeconfig

    - name: setting kube-admin config
      ansible.builtin.shell: |
        kubectl config set-cluster kubernetes-the-hard-way \
          --certificate-authority=ca.pem \
          --embed-certs=true \
          --server=https://127.0.0.1:6443 \
          --kubeconfig=admin.kubeconfig

        kubectl config set-credentials admin \
          --client-certificate=admin.pem \
          --client-key=admin-key.pem \
          --embed-certs=true \
          --kubeconfig=admin.kubeconfig

        kubectl config set-context default \
          --cluster=kubernetes-the-hard-way \
          --user=admin \
          --kubeconfig=admin.kubeconfig

        kubectl config use-context default --kubeconfig=admin.kubeconfig

    - name: copy to worker vm
      ansible.builtin.shell: scp -i ./{{ worker_name }} {{ worker_name }}.kubeconfig kube-proxy.kubeconfig {{ worker_name }}@{{ Worker_privateIP }}:~/

    - name: copy to controller vm
      ansible.builtin.shell: scp -i ./{{ cont_name }} admin.kubeconfig kube-controller-manager.kubeconfig kube-scheduler.kubeconfig {{ cont_name }}@{{ Controller_privateIP }}:~/

    - name: copy encryption file to controller vm
      ansible.builtin.shell: scp -i ~/{{ cont_name }} encryption-config.yaml {{ cont_name }}@{{ Controller_privateIP }}:~/

    - name: Running controller.yaml
      ansible.builtin.shell: 
        ansible-playbook -i /home/terra-bas/remote_inventry.ini -u {{ cont_name }} /home/terra-bas/controller.yaml --private-key=/home/terra-bas/{{ cont_name }}

    - name: Running worker.yaml
      ansible.builtin.shell: 
        ansible-playbook -i /home/terra-bas/remote_inventry.ini -u /home/terra-bas/{{ worker_name }} worker.yaml --private-key=/home/terra-bas/{{ worker_name }}
```
