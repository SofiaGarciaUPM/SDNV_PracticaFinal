FROM      osrg/ryu

RUN apt-get clean
RUN	apt-get update && apt-get install -y \
	net-tools \
	iproute \
	inetutils-ping \
    openvswitch-switch \
    openvswitch-common \
    iperf \
    tcpdump \
    python-pip \
    git

#RUN pip install -r ryu/tools/optional-requires
RUN git clone https://github.com/martimy/flowmanager

# Copiar qos_simple_switch_13.py si se necesita aquí
COPY qos_simple_switch_13.py /root/qos_simple_switch_13.py
