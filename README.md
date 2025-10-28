# WebServer Setup

## Check and setup network interface on a fresh VM

```bash
ping -c3 8.8.8.8
ping -c3 google.com
```

If not working 

```bash
ip link
sudo ip link set eth0 up
sudo udhcpc -i eth0
```

## Add ditro repositories

When alpine installed from iso image, there will be no repositories. Let's add  them.

```bash
cat /etc/alpine-release

vi /etc/apk/repositories

#add the the repos

https://dl-cdn.alpinelinux.org/alpine/v3.22/main
https://dl-cdn.alpinelinux.org/alpine/v3.22/community

#save and exit

apk update
```



## Download and execute the setup script

```bash
wget -qO- https://raw.githubusercontent.com/maxim-shaw/webserver-setup/refs/heads/main/setup_alpine.sh | sh
```

## Add public ssh key of a managing workstation to the to the authorized keys of a managed workstation

```bash
echo "ssh-ed25519 AAAAC3N....CM infra-deployer" >> /home/infra_si/.ssh/authorized_keys
```