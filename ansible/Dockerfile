FROM ubuntu:latest

RUN apt update && \
    apt upgrade -y && \
    ln -fs /usr/share/zoneinfo/Europe/Moscow /etc/localtime && \
    echo "Europe/Moscow" > /etc/timezone && \
    apt install python3 git curl wget iputils-ping iputils-tracepath vim sudo gpg ca-certificates -y && \
    useradd -m -s /bin/bash ansible && \
    echo "ansible:123" |  chpasswd && \
    sed -i 's/^%sudo[[:space:]]\+ALL=(ALL:ALL)[[:space:]]\+ALL$/%sudo   ALL=(ALL:ALL) NOPASSWD: ALL/p' /etc/sudoers && \
    usermod -aG sudo ansible && \
    curl -fsSL "https://keyserver.ubuntu.com/pks/lookup?op=get&search=0x93C4A3FD7BB9C367" | gpg --dearmor | sudo tee /usr/share/keyrings/ansible-archive-keyring.gpg && \
    printf "%s\n" \
    "deb [signed-by=/usr/share/keyrings/ansible-archive-keyring.gpg] https://ppa.launchpadcontent.net/ansible/ansible/ubuntu noble main" \
    "deb-src [signed-by=/usr/share/keyrings/ansible-archive-keyring.gpg] https://ppa.launchpadcontent.net/ansible/ansible/ubuntu noble main" \
    > /etc/apt/sources.list.d/ansible.list && \
    apt update && \
    apt install ansible -y

CMD ["sleep", "infinity"]