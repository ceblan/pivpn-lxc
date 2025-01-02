do_install_pivpn() {
    #curl -L https://install.pivpn.io | bash

    setupVars=/etc/pivpn/setupVars.conf
    if [ -e "${setupVars}" ]; then
      sed -i.update.bak '/pivpnUser/d;/UNATTUPG/d;/pivpnInterface/d;/IPv4dns/d;/IPv4addr/d;/IPv4gw/d;/pivpnProto/d;/PORT/d;/ENCRYPT/d;/DOWNLOAD_DH_PARAM/d;/PUBLICDNS/d;/OVPNDNS1/d;/OVPNDNS2/d;/SERVER_NAME/d;' "${setupVars}"
    else
      mkdir -p /etc/pivpn
      touch "${setupVars}"
    fi
    {
      echo "pivpnUser=${NORMAL_USER}"
      echo "UNATTUPG=\"unattended-upgrades\""
      echo "pivpnInterface=${NET_INTERFACE}"
      echo "IPv4dns=127.0.0.1"
      echo "IPv4addr=${INTERNALIP}"
      echo "IPv4gw=${GATEWAYIP}"
      echo "pivpnProto=udp"
      echo "PORT=${PIVPN_PORT}"
      echo "ENCRYPT=${PIVPN_KEY_SIZE}"
      echo "DOWNLOAD_DH_PARAM=false"
      echo "PUBLICDNS=${EXTERNALFQDN}"
      echo "OVPNDNS1=${OVPNDNS1}"
      echo "OVPNDNS2=${OVPNDNS2}"
      echo "SERVER_NAME=server"
    }>> "${setupVars}"

    cd /etc/pivpn
    wget https://raw.githubusercontent.com/pivpn/pivpn/master/auto_install/install.sh
    chmod +x install.sh
    ./install.sh --unattended > $LOG_DIR/pivpn_install.log
    #rm install.sh

    do_pivpn_add_user

    # https://github.com/pivpn/pivpn/wiki/FAQ#installing-with-pi-hole
    if [ -f $LOCK_DIR/pi-hole-installed.lock ]; then
      do_ask_hostnames
      service dnsmasq stop
      #nano /etc/dnsmasq.d/99-vpn.conf
      cat > /etc/dnsmasq.d/99-vpn.conf <<DNSMASQCONF
listen-address=127.0.0.1, $INTERNALIP, 10.8.0.1
DNSMASQCONF
      service dnsmasq start
    fi
  fi
}

do_pivpn_add_user() {
  # add user
  PIVPN_CLIENT_NAME=$(hostname)

  pivpn add --name=$PIVPN_CLIENT_NAME -p $PIVPN_PASSWD

  if [ -f $LOCK_DIR/postfix-installed.lock ]; then
    cat > ~/vpnmail.txt <<EOF
This is your VPN Certificate file. Please import it with your OpenVPN client to connect to $HOSTNAME.
Have a nice day!
EOF
    mail -s "OpenVPN Configuration" --attach=/home/$NORMAL_USER/ovpns/$PIVPN_CLIENT_NAME.ovpn $MAIL_FROM_ADDRESS@$MAIL_DOMAIN < ~/vpnmail.txt
    rm ~/vpnmail.txt
  fi
}

do_install_pivpn

# TODO fail2ban: http://eon01.com/blog/brute-force-secure-openvpn-with-fail2ban/
