#!/bin/bash
sudo apt-get update -y
sudo apt-get upgrade -y
main() {
  installTomcat
}

installTomcat() {
  sudo apt-get install default-jre -y
  curl -O https://archive.apache.org/dist/tomcat/tomcat-8/v8.5.65/bin/apache-tomcat-8.5.65.tar.gz
  sudo mkdir /opt/tomcat
  sudo tar xzvf apache-tomcat-8.5.65.tar.gz -C /opt/tomcat --strip-components=1
  ##To add to java certs from apache tomcat
  #sudo chown -R ubuntu:ubuntu /opt/java/jre1.8.0_212/lib/security
  cd /opt/tomcat || exit
  sudo chgrp -R ubuntu /opt/tomcat
  sudo chmod -R g+r conf
  sudo chmod g+x conf
  sudo chown -R ubuntu webapps/ work/ temp/ logs/
  sudo tee -a /etc/systemd/system/tomcat.service <<EOT
[Unit]
Description=Apache Tomcat Web Application Container
After=network.target

[Service]
Type=forking

Environment=CATALINA_PID=/opt/tomcat/temp/tomcat.pid
Environment=CATALINA_HOME=/opt/tomcat
Environment=CATALINA_BASE=/opt/tomcat
Environment='CATALINA_OPTS=-Xms512M -Xmx1024M -server -XX:+UseParallelGC'
Environment='JAVA_OPTS=-Djava.awt.headless=true -Djava.security.egd=file:/dev/./urandom'

ExecStart=/opt/tomcat/bin/startup.sh
ExecStop=/opt/tomcat/bin/shutdown.sh

User=ubuntu
Group=ubuntu
UMask=0007
RestartSec=10
Restart=always

[Install]
WantedBy=multi-user.target
EOT
  sudo systemctl daemon-reload
  sudo apt-get --no-install-recommends -y install apache2
  sudo a2enmod proxy
  sudo a2enmod proxy_http
  sudo a2enmod proxy_balancer
  sudo a2enmod lbmethod_byrequests
  cd ~ || exit
  sudo rm /etc/apache2/sites-available/000-default.conf
  sudo tee -a /etc/apache2/sites-available/000-default.conf <<EOT
  <VirtualHost *:80>
	# The ServerName directive sets the request scheme, hostname and port that
	# the server uses to identify itself. This is used when creating
	# redirection URLs. In the context of virtual hosts, the ServerName
	# specifies what hostname must appear in the request's Host: header to
	# match this virtual host. For the default virtual host (this file) this
	# value is not decisive as it is used as a last resort host regardless.
	# However, you must set it for any further virtual host explicitly.
	#ServerName www.example.com
ProxyPreserveHost On

    ProxyPass / http://127.0.0.1:8080/
    ProxyPassReverse / http://127.0.0.1:8080/
	ServerAdmin webmaster@localhost
	DocumentRoot /var/www/html

	# Available loglevels: trace8, ..., trace1, debug, info, notice, warn,
	# error, crit, alert, emerg.
	# It is also possible to configure the loglevel for particular
	# modules, e.g.
	#LogLevel info ssl:warn

	ErrorLog ${APACHE_LOG_DIR}/error.log
	CustomLog ${APACHE_LOG_DIR}/access.log combined

	# For most configuration files from conf-available/, which are
	# enabled or disabled at a global level, it is possible to
	# include a line for only one particular virtual host. For example the
	# following line enables the CGI configuration for this host only
	# after it has been globally disabled with "a2disconf".
	#Include conf-available/serve-cgi-bin.conf
</VirtualHost>
<VirtualHost *:443>
    ProxyPreserveHost On

    ProxyPass / http://127.0.0.1:8443/
    ProxyPassReverse / http://127.0.0.1:8443/
</VirtualHost>

# vim: syntax=apache ts=4 sw=4 sts=4 sr noet
EOT
  sudo systemctl enable tomcat
  sudo systemctl enable apache2
  sudo systemctl restart tomcat
  sudo systemctl restart apache2
  cd ~ || exit
  rm *.tar.gz
  sudo rm /opt/java/*.gz
  sudo sed -i 's/52428800/209715200/g' /opt/tomcat/webapps/manager/WEB-INF/web.xml
  allowManagerAccess
  echo "#####Tomcat installed##########"

}
allowManagerAccess() {
  PASSWORD="$(head /dev/urandom | tr -dc A-Za-z0-9 | head -c 13)"
  s1="<user username=\"manager\" password=\""
  s2="\"  roles=\"manager-gui,admin-gui\"/>"
  s3=$s1$PASSWORD$s2
  echo "##############################################################################################"
  echo "                                                                                              "
  echo "                                                                                              "
  echo "            The password for tomcat manager is: $PASSWORD                                     "
  echo "                                                                                              "
  echo "                                                                                              "
  echo "##############################################################################################"

  sudo sed -i "\$i $s3" /opt/tomcat/conf/tomcat-users.xml
  sudo sed -i '/org.apache.catalina.core.JreMemoryLeakPreventionListener/c\<Listener className="org.apache.catalina.core.JreMemoryLeakPreventionListener" driverManagerProtection="false"/>' /opt/tomcat/conf/server.xml
  sudo mkdir -p /opt/tomcat/conf/Catalina/localhost
  if [ -e /opt/tomcat/conf/Catalina/localhost/host-manager.xml ]; then
    sudo rm /opt/tomcat/conf/Catalina/localhost/host-manager.xml
  fi
  cat >~/host-manager.xml <<EOF
<Context privileged="true" antiResourceLocking="false"
        docBase="\${catalina.home}/webapps/host-manager">
    <Valve className="org.apache.catalina.valves.RemoteAddrValve" allow="^.*\$" />
</Context>
EOF
  sudo mv ~/host-manager.xml /opt/tomcat/conf/Catalina/localhost/host-manager.xml
  sudo systemctl restart tomcat
}
main
