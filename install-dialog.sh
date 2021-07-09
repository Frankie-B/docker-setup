#!/usr/bin/env bash

if [ "$EUID" -ne 0 ]; then
  dialog --title "Root" --msgbox 'Please run this file as root' 8 44
  clear
  exit 1
fi

if [ ! -f "/etc/xcomuser" ]; then
  echo $SUDO_USER > /etc/xcomuser
fi

FIRSTRUN=1
originstalldir=
while [[ -z $originstalldir ]]; do
  exec 3>&1
  originstalldir=$(dialog --inputbox "Please enter full path to install directory $exitcode $res" 6 60 2>&1 1>&3)
  exitcode=$?;
  exec 3>&-;
  if [ ! $exitcode = "0" ]; then
    clear
    exit $exitcode
  fi
done

installdir=$(echo $originstalldir | sed 's:/*$::')

if [ ! -d $installdir ]; then
  mkdir -p $installdir
else
  #echo "Existing installation found, continue setup to update docker-compose file and other dependencies"
  FIRSTRUN=0
fi

if [ ! -f /usr/local/bin/enter ]; then
  cp dep/enter /usr/local/bin/enter
  chmod +x /usr/local/bin/enter
fi

if [ ! -f /usr/local/bin/devctl ]; then
  cp dep/devctl /usr/local/bin/devctl
  sed -i -e 's:installdirectory:'"$installdir"':g' /usr/local/bin/devctl
  chmod +x /usr/local/bin/devctl
fi

## updates

#echo "Running updates"
#apt -qq update 
# apt -qq -y upgrade // a bit heavy, especially if there are packages you don't want to upgrade
# install docker dependencies
#DEBIAN_FRONTEND=noninteractive apt -y -qq install curl git software-properties-common apt-transport-https gnupg-agent ca-certificates
# removed parted, xfsprogs, ntpdate
# exim does not come with ubuntu default install
#apt -y purge exim4 exim4-base exim4-config exim4-daemon-light && apt-get -y autoremove

## end updates

## docker and docker-compose

if [ ! -f /usr/bin/docker ] && [[ ! -f /usr/local/bin/docker-compose || ! -f /usr/local/docker-compose ]]; then
  if dialog --stdout --title "Docker and docker-compose not found, want me to install both?" \
            --backtitle "docker & docker-compose" \
            --yesno "Yes: Install docker, No: Continue installation" 7 60; then
      #dialog --title "Information" --msgbox "TRUE" 6 44
      if [[ ! -f /usr/bin/docker && -n "$(uname -v | grep Ubuntu)" ]]; then
      # not sure if this will work, untested
      #echo "Installing docker"
      curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -
      apt-key fingerprint 0EBFCD88
      RELEASE=$(lsb_release -cs)
      add-apt-repository \
      "deb [arch=amd64] https://download.docker.com/linux/ubuntu \
      $RELEASE \
      stable"
      apt -qq update
      apt -y install docker-ce
    fi
    if [ ! -f /usr/local/bin/docker-compose ]; then
      echo "Installing docker-compose"
      curl -L "https://github.com/docker/compose/releases/download/1.25.4/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
      chmod +x /usr/local/bin/docker-compose
    fi
  else
      dialog --title "Information" --msgbox "You can download both at \n https://docs.docker.com/install/ \n https://docs.docker.com/compose/install/" 7 50
  fi
fi
## end docker and docker-compose

## prepare paths

if [ ! -d "$installdir/data/shared/sites" ]; then
  mkdir -p $installdir/data/shared/sites
  #chown -R web.web $installdir/data/shared/sites
fi

if [ ! -d "$installdir/data/shared/media" ]; then
  mkdir -p $installdir/data/shared/media
  #chown -R web.web $installdir/data/shared/media
fi

if [ ! -d "$installdir/data/shared/sockets" ]; then
  mkdir -p $installdir/data/shared/sockets
fi

if [ ! -d "$installdir/data/home" ]; then
  mkdir -p $installdir/data/home
fi

if dialog --stdout --title "Skip configurator versioning post-checkout / post-merge?" \
            --backtitle "git hooks" \
            --yesno "Yes: Skip configurator, No: Continue installation" 7 60; then
  SKIP_CONFIGURATOR=1
fi

cmd=(dialog --separate-output --checklist "Select PHP versions:" 22 76 16)
options=(php56 "PHP 5.6" off    # any option can be set to default to "on"
         php70 "PHP 7.0" off
         php71 "PHP 7.1" off
         php72 "PHP 7.2" off
         php73 "PHP 7.3" on
         php74 "PHP 7.4" on
         php80 "PHP 8.0" off)
paths=$("${cmd[@]}" "${options[@]}" 2>&1 >/dev/tty)
clear
#for path in "${paths[@]}"
for path in paths
do :
  if [ ! -d "$installdir/data/home/$path" ]; then
    mkdir -p "$installdir/data/home/$path"
    cp -R /etc/skel/. $installdir/data/home/$path
    echo "alias m2='magerun2'" >> $installdir/data/home/$path/.bash_aliases
  fi
  if [ ! -f "$installdir/data/home/$path/.zshrc" ]; then
    cp dep/zshrc $installdir/data/home/$path/.zshrc
  fi
  if ! grep -q "export TERM=xterm" $installdir/data/home/$path/.bashrc; then
    echo "export TERM=xterm" >> $installdir/data/home/$path/.bashrc
  fi
  if ! grep -q "\$HOME/bin" $installdir/data/home/$path/.bashrc; then
    echo "PATH=\$HOME/bin:\$PATH" >> $installdir/data/home/$path/.bashrc
  fi
  if [ $SKIP_CONFIGURATOR = "1" ]; then
    echo "export SKIP_CONFIGURATOR=1" >> $installdir/data/home/$path/.bashrc
    echo "export SKIP_CONFIGURATOR=1" >> $installdir/data/home/$path/.zshrc
  fi
  if [ ! -f "$installdir/data/home/$path/git-autocomplete.sh" ]; then
    cp dep/git-autocomplete.sh $installdir/data/home/$path/
    chmod +x $installdir/data/home/$path/git-autocomplete.sh
  fi
  if [ ! -d "$installdir/data/home/$path/bin" ]; then
    mkdir -p "$installdir/data/home/$path/bin"
  fi
  if [ ! -f "$installdir/data/home/$path/bin/redis-cli" ]; then
    cp dep/redis-cli $installdir/data/home/$path/bin/
  fi
done

if [ ! -d "$installdir/docker" ]; then
  mkdir -p $installdir/docker
fi

## end prepare paths

## gitconfig
#read -p "[git config] Configure gitconfig options? [y/N] " -n 1 -r
#echo    # (optional) move to a new line
#if [[ $REPLY =~ ^[Yy]$ ]]
#then

if dialog --stdout --title "Configure gitconfig options?" \
            --backtitle "git config" \
            --yesno "Yes: Configure git config, No: Continue installation" 7 60; then
  if [ ! -d "$installdir/docker/dependencies" ]; then
    mkdir -p $installdir/docker/dependencies
    cp ./dep/gitconfig $installdir/docker/dependencies/
  fi
  name=$(dialog --inputbox "Please enter your name" 6 60  --output-fd 1)
  #echo "[gitconfig] Please enter your name"
  #read name
  sed -i -e 's:username:'"$name"':g' $installdir/docker/dependencies/gitconfig

  email=$(dialog --inputbox "Please enter e-mail address" 6 60  --output-fd 1)
  #echo "[gitconfig] Please enter your e-mail address"
  #read email
  sed -i -e 's:user@email.com:'"$email"':g' $installdir/docker/dependencies/gitconfig
  for path in "${paths[@]}"
  do :
    cp $installdir/docker/dependencies/gitconfig $installdir/data/home/$path/.gitconfig
  done

  # cleanup as there's no need for this anymore
  if [ -d "$installdir/docker/dependencies" ]; then
    rm -r $installdir/docker/dependencies
  fi
fi
## end gitconfig

## ssh

if [ -f "/home/$SUDO_USER/.ssh/id_rsa" ]; then
if dialog --stdout --title "Found ssh key at /home/$SUDO_USER/.ssh/id_rsa, do you want to copy this?" \
            --backtitle "ssh" \
            --yesno "Yes: Configure ssh keys, No: Continue installation" 7 60; then
  #read -p "Found ssh key at /home/$SUDO_USER/.ssh/id_rsa, do you want to copy this? [y/N]" -n 1 -r
  #echo    # (optional) move to a new line
  #if [[ $REPLY =~ ^[Yy]$ ]]
  #then
    #for path in "${paths[@]}"
    for path in paths
    do :
      echo $path
      if [ ! -d $installdir/data/home/$path/.ssh ]; then
        mkdir $installdir/data/home/$path/.ssh
      fi
      # also use ssh config if found
      if [ -f "/home/$SUDO_USER/.ssh/config" ]; then
        cp /home/$SUDO_USER/.ssh/config $installdir/data/home/$path/.ssh/
      fi
      if [ -d "/home/$SUDO_USER/.ssh/X-com" ]; then
        cp -r /home/$SUDO_USER/.ssh/X-com $installdir/data/home/$path/.ssh/
      fi
      cp /home/$SUDO_USER/.ssh/id_rsa $installdir/data/home/$path/.ssh/
      cp /home/$SUDO_USER/.ssh/id_rsa.pub $installdir/data/home/$path/.ssh/
      # chmod -r 400 $installdir/data/home/$path/.ssh/*
    done
  fi
fi

## end ssh

## docker compose

# replace existing docker compose with new to update settings after a second install
cp ./docker/docker-compose.yml $installdir/docker/docker-compose.yml
cp -r ./docker/* $installdir/docker/

#read -p "Do you want docker containers to restart automatically? [y/N] " -n 1 -r
#echo    # (optional) move to a new line
#if [[ $REPLY =~ ^[Yy]$ ]]
#then
if dialog --stdout --title "Do you want docker containers to restart automatically" \
            --backtitle "auto restart" \
            --defaultno \
            --yesno "Yes: Always restart, No: No restart" 7 60; then
    sed -i -e 's/# restart: always/restart: always/g' $installdir/docker/docker-compose.yml
fi

if [ -f "$installdir/docker/docker-compose.yml" ]; then
  #echo "Setting up correct values for docker-compose based on your given installdir"
  sed -i -e 's:installdirectory:'"$installdir"':g' $installdir/docker/docker-compose.yml
fi

## end docker compose

if [ ! $FIRSTRUN = "0" ]; then
  chown -R $SUDO_USER:$SUDO_USER $installdir/data/home/*
  chown -R $SUDO_USER:$SUDO_USER $installdir/data/shared/sites
  chown -R $SUDO_USER:$SUDO_USER $installdir/docker
  # set max_map_count for sonarqube
  # sysctl -w vm.max_map_count=262144
  # make it permanent
  echo "vm.max_map_count=262144" > /etc/sysctl.d/sonarqube.conf
  echo "fs.inotify.max_user_watches = 524288" > /etc/sysctl.d/inotify.conf
  sysctl -p --system

fi

dialog --title "Complete" --msgbox "Installation prepared \n 
1: Change directory to $installdir/docker \n
2: run docker-compose up -d \n
3: get some coffee as this might take some time \n
" 9 53
clear
exit 0