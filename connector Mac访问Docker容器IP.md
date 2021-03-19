Mac访问Docker容器IP

wenjun_xiao 2020-05-25 10:27:51   3047   收藏 8    原力计划
分类专栏： Docker Mac GO 文章标签： docker go 网络 mac os x
版权

#文章目录

问题
解决
第一步、Mac
第二步、Docker
其他机器

分析
方案
安装
Mac
Docker
其他机器
验证
宿主机器访问容器
其他机器访问容器

#问题

Docker for Mac无法在macOS通过IP直接访问Docker中容器，只能通过EXPOSE端口来访问，这个问题在官方文档中有描述，对于大多数情况EXPOSE是够用的。但是对于测试某些集群的时候就会有问题，比如搭建HBase集群，集群会有很多容器使用相同端口，节点注册到zookeeper上的是容器内的IP或机器名，要想在宿主机器上访问就必须能够访问节点IP。另外，除了自己访问之外，为了分享或者测试，还需临时把搭建好的环境提供给其他同事。因此，主要的问题如下：

需要支持从macOS访问容器IP的能力
需要支持从其他机器访问容器IP的能力

#解决

先给出解决方法，如有兴趣再查看分析过程

Mac端和Docker端都默认使用了192.168.251.1/24的子网。如果Mac端已经被占用了，可在配置文件docker-connector.conf中新增addr xxx.xxx.xxx.1/24的地址（默认注释掉了）；如果Docker端冲突了，需要修改启动容器的命令追加mac-receiver -addr xxx.xxx.xxx.1/24来指定地址

```shell
#!/bin/bash

echo ">>>>>> Installing docker-connector..."
brew install wenjunxiao/brew/docker-connector
echo "<<<<<< Install Finish"
echo ""
echo ">>>>>> Starting Docker Daemon..."
open -a Docker
closed=1
while [ $closed -eq 1 ]
do
    sleep 1
    docker info >> /dev/null 2>&1
    closed=$?
done
echo "Docker Daemon is ready!"


sudo sed -i '/expose/d' /usr/local/etc/docker-connector.conf
sudo sed -i '/token/d' /usr/local/etc/docker-connector.conf

docker network ls --filter driver=bridge --format "{{.ID}}" | xargs docker network inspect --format "route {{range .IPAM.Config}}{{.Subnet}}{{end}} expose" >> /usr/local/etc/docker-connector.conf

sudo brew services start docker-connector
```



##第一步 Mac：安装，配置，运行connector

mac端通过brew安装docker-connector

```shell
$ brew install wenjunxiao/brew/docker-connector
```

安装完成，按照提示通过命令添加路由，以下命令把所有bridge的网络都添加到路由中

```shell
$ docker network ls --filter driver=bridge --format "{{.ID}}" | xargs docker network inspect --format "route {{range .IPAM.Config}}{{.Subnet}}{{end}}" >> /usr/local/etc/docker-connector.conf

$ docker network ls --filter driver=bridge --format "{{.ID}}" | xargs docker network inspect --format "route {{range .IPAM.Config}}{{.Subnet}}{{end}} expose" >> /usr/local/etc/docker-connector.conf
```

也可以手动修改/usr/local/etc/docker-connector.conf文件中的路由，格式是

```
route 172.100.0.0/16
```

路由的子网决定了你能访问那些容器，配置完成，直接启动服务（需要sudo）

```shell
$ sudo brew services start docker-connector
```

路由配置启动之后仍然可以修改，并且无需重启服务立即生效。
为了把对应的网络共享给其他同事访问，需要对配置文件进行如下调整：

```shell
vi /usr/local/etc/docker-connector.conf

# 在route后增加expose
route 172.17.0.0/16 expose
route 172.18.0.0/16 expose
route 172.19.0.0/16 expose

# 增加监听地址和token及其IP分配
expose 0.0.0.0:2512
token user1 192.168.251.10
token user2 192.168.251.11
```

这样设置后，外部可以安装docker-accessor，使用对应token进行连接，访问容器网络。



##第二步 Docker：运行container

docker端运行wenjunxiao/mac-docker-connector，需要使用host网络，并且允许NET_ADMIN

```shell
$ docker run -it -d --restart always --net host --cap-add NET_ADMIN --name connector wenjunxiao/mac-docker-connector
```

##第三步 访问：安装，运行accessor

其他机器如果想要访问你本地容器需要安装docker-accessor，不同的系统安装方法不同

##MacOS

macOS直接用brew安装

```shell
$ brew install wenjunxiao/brew/docker-accessor
```


安装完成之后，需要从容器提供者获取地址和token之后使用sudo运行

```shell
$ sudo docker-accessor -remote 192.168.1.104:2512 -token user1

# 192.168.1.104为mac的地址
```



## Windows

需要先安装tap驱动tap-windows，安装完成驱动之后直接从mac-docker-connector下载最新适合当前操作系统的docker-accessor-win-i686.zip或docker-accessor-win-x86_64.zip解压即可，运行时需要管理员权限打开控制台

Windows
需要先安装tap驱动tap-windows，安装完成驱动之后直接从mac-docker-connector下载最新适合当前操作系统的docker-accessor-win-i686.zip或docker-accessor-win-x86_64.zip解压即可，运行时需要管理员权限打开控制台

D:\Downloads\>.\docker-accessor.exe -remote 192.168.1.100:2512 -token user2

Linux
Linux系统直接从mac-docker-connector下载最新的docker-accessor-linux.tar.gz解压即可

$ curl -L -o- https://github.com/wenjunxiao/mac-docker-connector/releases/download/v2.0/docker-accessor-linux.tar.gz | tar -xzf - -C /usr/local/bin

获取访问地址和token之后直接运行（需要sudo）

$ sudo docker-accessor -remote 192.168.1.100:2512 -token user1



#分析

阅读过一篇Mac访问容器的文章。思路很简单，宿主和Docker的虚拟机容器是两个独立的网络，使用EXPOSE端口使得macOS能够访问Docker的容器，再以使用host网络模式的Docker容器与Docker虚拟机处于同一网络中，使用转发串联两个容器。虽然达到了目的，但是过程稍微有点绕。想要简单一点的方案。

```
+------------+          +-----------------+
|            |          |    Hypervisor   |
|   macOS    |          |  +-----------+  |
|            |          |  | Container |  |
|            |          |  +-----------+  |
|     Client |<-------->|       Server    |
+------------+          +-----------------+
```

由于macOS不能直接访问容器，以及容器选择host网络模式时不允许EXPOSE端口导致需要增加一个socat容器来做转发。但是容器是可以访问macOS，通过host.docker.internal这个域名就可以访问。由于网络连接是双向的，哪个是客户端，哪个是服务端都可以。因此，我们可以反转一下角色

```
+------------+          +-----------------+
|            |          |    Hypervisor   |
|   macOS    |          |  +-----------+  |
|            |          |  | Container |  |
|            |          |  +-----------+  |
|     Server |<-------->|       Client    |
+------------+          +-----------------+
```

这样就不需要EXPOSE端口以及新增一个容器来转发了。
即使这样，对于macOS访问容器IP这个简单目的而言，安装配置证书还是稍显麻烦，而且也大材小用了。

方案

借助于上面这个思路，我们只需要实现一个支持路由转发的客户端和服务端即可。

```
+------------+          +-----------------+
|            |          |    Hypervisor   |
|   macOS    |          |  +-----------+  |
|            |          |  | Container |  |
|            |   udp    |  +-----------+  |
| TUN Server |<-------->|   TUN Client    |
+------------+          +-----------------+
```

依托于客户端和服务器端的TUN设备，把路由到虚拟网络设备的数据包转发到对端的虚拟网络设备即可实现网络的互通了。因此主要步骤有两步：
1、在macOS和容器中创建虚拟网卡
2、交换虚拟网卡的数据包
以下是GO的实现方法。
1、容器中创建虚拟网卡

```
import "github.com/songgao/water"
func main(){
  config := water.Config{
    DeviceType: water.TUN,
  }
  // 新建虚拟网卡
  iface, err := water.New(config)
  if err != nil {
    logger.Fatal(err)
  }
  // 启用并设置mtu
  exec.Command("ip", "link", "set","dev", iface.Name(), "up", "mtu", "1400").Run()
  // 设置IP信息
  exec.Command("ip", "addr", "add","dev", iface.Name(), "local", "192.168.251.1", "peer", "192.168.251.2").Run()
  // 添加路由
  exec.Command("ip", "route", "add","192.168.251.0/24", "via", "192.168.251.2", "dev", iface.Name()).Run()
}
```

2、macOS中创建虚拟网卡

```
import "github.com/songgao/water"
func main(){
  config := water.Config{
    DeviceType: water.TUN,
  }
  // 新建虚拟网卡
  iface, err := water.New(config)
  if err != nil {
    logger.Fatal(err)
  }
```

  // 启用并设置IP信息

```
  exec.Command("ifconfig", iface.Name(), "inet", "192.168.251.2", "192.168.251.1", "netmask", "255.255.255.255", "up").Run()
  // 添加Docker中的子网络到路由表中，可以添加多个
  exec.Command("route", "-n", "add", "-net", "172.17.0.0/16", "192.168.251.1").Run()
}
```

3、把虚拟网卡数据包通过udp转发到对端

// 虚拟网卡通过udp转发

```
go func() {
  buf := make([]byte, 2000)
  for {
    n, err := iface.Read(buf)
    if err != nil {
	  fmt.Printf("tun read error: %v\n", err)
	  continue
	}
	if _, err := conn.Write(buf[:n]); err != nil {
	  fmt.Printf("udp write error: %v\n", err)
	}
  }
}()
// 把udp收到的数据包写入虚拟网卡
data := make([]byte, 2000)
for {
  n, err := conn.Read(data)
  if err != nil {
    fmt.Println("failed read udp msg, error: " + err.Error())
  }
  if _, err := iface.Write(data[:n]); err != nil {
    fmt.Printf("tun write error: %v\n", err)
  }
}
```


通过以上步骤就可以完成数据交换了。
同样的为了共享给其他同事，只需要在对应的电脑上启动一个客户端进行数据交换即可。
完整的源码地址如下：
https://github.com/wenjunxiao/mac-docker-connector


通过以上步骤就可以完成数据交换了。
同样的为了共享给其他同事，只需要在对应的电脑上启动一个客户端进行数据交换即可。
完整的源码地址如下：
https://github.com/wenjunxiao/mac-docker-connector

#安装

##Mac

mac端也已经编译好，并添加了第三方的Homebrew，可以通过brew安装

```
$ brew install wenjunxiao/brew/docker-connector
```


安装完成，按照提示通过命令添加路由，以下命令把所有bridge的网络都添加到路由中

```
$ docker network ls --filter driver=bridge --format "{{.ID}}" | xargs docker network inspect --format "route {{range .IPAM.Config}}{{.Subnet}}{{end}}" >> /usr/local/etc/docker-connector.conf
```


也可以手动修改/usr/local/etc/docker-connector.conf文件中的路由，格式是

```
route 172.100.0.0/16
```


配置完成，可以直接启动服务（需要sudo）

```
$ sudo brew services start docker-connector
```


启动之后如果新增了网络，或者需要删除，可以直接修改配置文件，无需要重启服务，路由会自动更新。可以通过以下命令查看路由表

```
$ netstat -nr -f inet
```


##Docker

docker端已经打包成镜像，可以直接使用：
https://hub.docker.com/repository/docker/wenjunxiao/mac-docker-connector

```
$ docker pull wenjunxiao/mac-docker-connector
```

直接启动即可，需要使用host网络，并且允许NET_ADMIN

直接启动即可，需要使用host网络，并且允许NET_ADMIN

```
$ docker run -it -d --restart always --net host --cap-add NET_ADMIN --name connector wenjunxiao/mac-docker-connector
```



#访问

对于需要访问共享容器网络的机器，只需要安装客户端docker-accessor并启动即可访问，不同系统上的安装方法在前面【解决】部分。

##验证

选择一个容器IP测试一下，我的测试IP是172.100.0.10，并在对应的容器中启动一个HTTP服务

```
$ python -m SimpleHTTPServer 8080
Serving HTTP on 0.0.0.0 port 8080 ...
```


##宿主机器访问容器

宿主机器访问容器

在宿主机器上直接ping和访问http服务

```
$ ping 172.100.0.10
PING 172.100.0.10 (172.100.0.10): 56 data bytes
64 bytes from 172.100.0.10: icmp_seq=0 ttl=63 time=0.837 ms
64 bytes from 172.100.0.10: icmp_seq=1 ttl=63 time=1.689 ms
64 bytes from 172.100.0.10: icmp_seq=2 ttl=63 time=2.793 ms
64 bytes from 172.100.0.10: icmp_seq=3 ttl=63 time=2.333 ms
```


再验证HTTP服务

再验证HTTP服务

```
$ curl -si -w "%{http_code}" http://172.100.0.10:8080 -o /dev/null
200
```


无法访问多网络容器
如果一个容器有多个网络（可以通过docker network connect添加），可能会导致ping不通，此时要在容器中增加路由表，或者修改默认路由。比如在172.100.0.10的容器中原来的路由表是

无法访问多网络容器
如果一个容器有多个网络（可以通过docker network connect添加），可能会导致ping不通，此时要在容器中增加路由表，或者修改默认路由。比如在172.100.0.10的容器中原来的路由表是

```
$ route
Kernel IP routing table
Destination     Gateway         Genmask         Flags Metric Ref    Use Iface
default         cpe-172-100-0-1 0.0.0.0         UG    0      0        0 eth0
172.100.0.0     0.0.0.0         255.255.0.0     U     0      0        0 eth0
```


但是通过docker network connect brigde container-id之后，路由表变成如下

但是通过docker network connect brigde container-id之后，路由表变成如下

```
$ route
Kernel IP routing table
Destination     Gateway         Genmask         Flags Metric Ref    Use Iface
default         gateway         0.0.0.0         UG    0      0        0 eth0
172.17.0.0      0.0.0.0         255.255.0.0     U     0      0        0 eth0
172.100.0.0     0.0.0.0         255.255.0.0     U     0      0        0 eth1
```

默认路由网关不是子网的网关，此时可以修改默认路由

```
$ip route del default
$ip route add default via 172.100.0.1
```

也可以把用于交换的虚拟网卡的子网(192.168.251.0/24)添加到当前容器的路由中

```
$ ip route add 192.168.251.0/24 via 172.100.0.1 dev eth1
```


这两种方式都可以保证容器可以通过172.100.0.10访问。

##其他机器访问容器

为了验证其他机器访问，在windows启动客户端docker-accessor.exe，用管理员打开控制台

C:\Users\wenjunxiao>.\docker-accessor.exe -remote 192.168.1.107:2512 -token win10
local => 192.168.1.109:49572
remote => 192.168.1.107:2512
relogin
logged
interface => "my-tap"
command => netsh interface ip set address "my-tap" static 192.168.251.3 255.255.255.0 192.168.251.2
command => netsh interface ip show addresses "my-tap"
waiting network setup...
command => netsh interface ip show addresses "my-tap"
waiting network setup...
command => netsh interface ip show addresses "my-tap"
waiting network setup...
command => netsh interface ip show addresses "my-tap"
command => netsh interface ip delete dns my-tap all
command => netsh interface ip delete wins my-tap all
control => addr 192.168.251.3/24
control => peer 192.168.251.2
control => mtu 1400
control => route 172.100.0.0/16
command => route add 172.100.0.0 mask 255.255.0.0 192.168.251.2

已经连接成功，打开另一个控制台测试是否可以访问

C:\Users\wenjunxiao>ping 172.100.0.10
正在 Ping 172.100.0.10 具有 32 字节的数据:
来自 172.100.0.10 的回复: 字节=32 时间=11ms TTL=63
来自 172.100.0.10 的回复: 字节=32 时间=11ms TTL=63
来自 172.100.0.10 的回复: 字节=32 时间=11ms TTL=63
来自 172.100.0.10 的回复: 字节=32 时间=13ms TTL=63

172.100.0.10 的 Ping 统计信息:
    数据包: 已发送 = 4，已接收 = 4，丢失 = 0 (0% 丢失)，
往返行程的估计时间(以毫秒为单位):
    最短 = 11ms，最长 = 13ms，平均 = 11ms

再测试一下HTTP

C:\Users\wenjunxiao>curl -si -w "%{http_code}" http://172.100.0.10:8080 -o /dev/null
200

可以正常访问
————————————————
版权声明：本文为CSDN博主「wenjun_xiao」的原创文章，遵循CC 4.0 BY-SA版权协议，转载请附上原文出处链接及本声明。
原文链接：https://blog.csdn.net/wenjun_xiao/article/details/106320242