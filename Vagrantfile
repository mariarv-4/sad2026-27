N = "7" # Tu número de clase
iniciales = "MRV"

# Secretos (contraseñas): se leen del fichero .env, que NO se sube a Git
secretos = {}
if File.exist?(".env")
  File.readlines(".env").each do |linea|
    clave, valor = linea.strip.split("=", 2)
    secretos[clave] = valor if valor && !clave.start_with?("#")
  end
end

Vagrant.configure("2") do |config|

  # Definición del equipo gw
  config.vm.define "gw" do |gw|
    gw.vm.box = "bento/ubuntu-24.04"
    gw.vm.hostname = "gw-#{iniciales}"
    # eth1: WAN (Mismo 'intnet' que el externo)
    gw.vm.network "private_network", ip: "203.0.113.254", netmask: "255.255.255.0", virtualbox__intnet: "red_wan"
    # eth2: DMZ
    gw.vm.network "private_network", ip: "172.1.#{N}.1", netmask: "255.255.255.0", virtualbox__intnet: "red_dmz" 
    # eth3: LAN
    gw.vm.network "private_network", ip: "172.2.#{N}.1", netmask: "255.255.255.0", virtualbox__intnet: "red_lan"
    # eth4: LAN de gestion o Intranet
    gw.vm.network "private_network", ip: "172.3.#{N}.1", netmask: "255.255.255.0", virtualbox__intnet: "red_gestion"
    gw.vm.provision "shell", path: "gw/provision.sh"   
    gw.vm.provider "virtualbox" do |vb|
        vb.name = "gw"
        vb.gui = false
        vb.memory = "768"
        vb.cpus = 1
        vb.linked_clone = true
        vb.customize ["modifyvm", :id, "--groups", "/sad"]
    end
  end        
  
# IDP en la LAN
  config.vm.define "idp" do |idp|
    idp.vm.box = "bento/ubuntu-24.04"
    idp.vm.hostname = "idp-#{iniciales}"
    idp.vm.network "private_network", ip: "172.3.#{N}.2", netmask: "255.255.255.0", virtualbox__intnet: "red_gestion"
    
    # Provisión principal pasando las variables de entorno de forma segura
    idp.vm.provision "shell", path: "idp/provision.sh", env: {
      "DOMINIO" => "#{iniciales}.internal",
      "ORGANIZACION" => "Empresa #{iniciales}",
      "LDAP_ADMIN_PASS" => secretos["LDAP_ADMIN_PASS"]
    }

    # Ruta por defecto robusta (usando replace para evitar fallos de carrera)
    idp.vm.provision "shell",
        run: "always",
        inline: "ip route replace default via 172.3.#{N}.1"      

    idp.vm.provider "virtualbox" do |vb|
        vb.name = "idp-intranet"
        vb.gui = false
        vb.memory = "512"
        vb.cpus = 1
        vb.linked_clone = true
        vb.customize ["modifyvm", :id, "--groups", "/sad"]
    end
  end

  # Adminpc en la LAN (Actualizado a Debian 13 para la Práctica 3)
  config.vm.define "adminpc" do |adminpc|
    adminpc.vm.box = "bento/debian-13"
    adminpc.vm.hostname = "adminpc-#{iniciales}"
    adminpc.vm.network "private_network", ip: "172.2.#{N}.10", netmask: "255.255.255.0", virtualbox__intnet: "red_lan"
    adminpc.vm.provision "file", source: "adminpc/claves-ssh/clave_admin_privada", destination: "/tmp/id_ed25519"
    adminpc.vm.provision "file", source: "adminpc/claves-ssh/clave_admin.pub", destination: "/tmp/id_ed25519.pub"
    adminpc.vm.provision "shell", path: "adminpc/provision.sh"
    # Reemplazar la ruta por defecto
    adminpc.vm.provision "shell", run: "always", inline: "ip route replace default via 172.2.#{N}.1"   
    adminpc.vm.provider "virtualbox" do |vb|
        vb.name = "adminpc-lan"
        vb.gui = false
        vb.memory = "400"
        vb.cpus = 1
        vb.linked_clone = true
        vb.customize ["modifyvm", :id, "--groups", "/sad"]
    end
  end

# Empleado en la LAN (Actualizado a Debian 13 para la Práctica 3)
  config.vm.define "empleado" do |empleado|
    empleado.vm.box = "bento/debian-13"
    empleado.vm.hostname = "empleado-#{iniciales}"
    empleado.vm.network "private_network", ip: "172.2.#{N}.100", netmask: "255.255.255.0", virtualbox__intnet: "red_lan"
    empleado.vm.provision "shell", path: "empleado/provision.sh"
    
    # Esta línea usa la variable 'empleado' pero ESTÁ DENTRO de su bloque do |empleado|
    empleado.vm.provision "shell", run: "always", inline: "ip route replace default via 172.2.#{N}.1; systemctl try-restart sssd || true"   
    
    empleado.vm.provider "virtualbox" do |vb|
        vb.name = "empleado-lan"
        vb.gui = false
        vb.memory = "400"
        vb.cpus = 1
        vb.linked_clone = true
        vb.customize ["modifyvm", :id, "--groups", "/sad"]
    end
  end

  # proxy en DMZ
  config.vm.define "proxy" do |proxy|
    proxy.vm.box = "bento/ubuntu-24.04"
    proxy.vm.hostname = "proxy-#{iniciales}"
    proxy.vm.network "private_network", ip: "172.1.#{N}.2", netmask: "255.255.255.0", virtualbox__intnet: "red_dmz" 
    proxy.vm.provision "shell", path: "proxy/provision.sh"
    # eliminar default gw en eth0 – red NAT creada por defecto
    proxy.vm.provision "shell",
        run: "always",
        inline:  "ip route del default && ip route add default via 172.1.#{N}.1"       
    proxy.vm.provider "virtualbox" do |vb|
        vb.name = "proxy-dmz"
        vb.gui = false
        vb.memory = "1024"
        vb.cpus = 1
        vb.linked_clone = true
        vb.customize ["modifyvm", :id, "--groups", "/sad"]
    end
  end

# WWW en DMZ (Actualizado a Debian 13 para la Práctica 3)
  config.vm.define "www" do |www|
    www.vm.box = "bento/debian-13"
    www.vm.hostname = "www-#{iniciales}"
    www.vm.network "private_network", ip: "172.1.#{N}.3", netmask: "255.255.255.0", virtualbox__intnet: "red_dmz"

    www.vm.provider "virtualbox" do |vb|
      vb.name = "www-dmz"
      vb.gui = false
      vb.memory = "400"
      vb.cpus = 1
      vb.linked_clone = true
      vb.customize ["modifyvm", :id, "--groups", "/sad"]
    end
    
    www.vm.provision "file", source: "adminpc/claves-ssh/clave_admin.pub", destination: "/tmp/id_ed25519.pub"
    www.vm.provision "shell", path: "www/provision.sh"

    # Reemplazar la ruta por defecto y reiniciar SSSD de forma segura dentro del bloque
    www.vm.provision "shell", run: "always", inline: "ip route replace default via 172.1.#{N}.1; systemctl try-restart sssd || true"
  end

 end