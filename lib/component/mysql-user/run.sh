#!/bin/sh

apk add -U py3-mysqlclient
ansible-playbook playbook.yml
