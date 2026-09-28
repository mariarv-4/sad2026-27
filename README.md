
# IES CELIA
Proyecto de prueba de la clase de 2º ASIR, de María Isabel Rodríguez Valentín

## 1. Estructura
Un ejemplo de lo que vamos a realizar

![alt text](image.png)

## 1. Gateway y Enrutador (`gw`)

Actúa como router central, cortafuegos y nodos VPN.

+ **SO**: Ubuntu 24.04
+ **Hostname**:`mvr`
1. `eth1`: 172.1.7.1
2. Pas2

##  2.1. LAN de Gestión / Intranet (`172.3.7.0/24`)

No tiene acceso directo desde Internet. Sale mediante `gw`.

+ Proveedor de Identidades (`idp`)

    + **SO**: Ubuntu 24.04

## Instruccioes para el despliegue

**2.1. Resquisitos precios**
Tener instalado lo siguiente:

+ Git

+ Virtualbox

+ Vagrant

**2.2. Despliegue**

1. Clonar este repositorio:

```bash
$ git clone https://github.com/mariarv-4/sad2026-27.git
```

2. Levantar con vagrant

  ```bash
$ cd SAD-PROYECTO-2026-26-solucion
$ vagrant up
```
3. Una vez levantado, comprobamos el estado de las máquinas con:
```bash
$ vagrant status
 ```
4. Y accedemos a las máquinas con `vagrant ssh máquina`. Ej para acceder a www:

```bash 
$ vagrant ssh www 
```