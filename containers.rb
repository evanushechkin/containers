require 'ohai/util/file_helper'

include Ohai::Util::FileHelper

Ohai.plugin(:Containers) do

  provides "containers"

  def create_objects

    containers Mash.new
    containers[:lxc] = Mash.new unless containers[:lxc]
    containers[:lxc][:container] = Mash.new unless containers[:lxc][:container]

    containers[:docker] = Mash.new unless containers[:docker]
    containers[:docker][:container] = Mash.new unless containers[:docker][:container]

  end

  def lxc_exists?

    which('lxc-ls')

  end

  def docker_exists?

    which('docker')

  end

  collect_data(:linux) do

    create_objects


    #Check if either or both exist
    containers[:lxc][:host] = lxc_exists?.to_s.include?('false') ? false : true
    containers[:docker][:host] = docker_exists?.to_s.include?('false') ? false : true


    #Set our command for lxc container
    lxc_command = "lxc-ls"
    docker_command = "docker ps -a"

    #Gather our containers
    lxc_containers = shell_out(lxc_command).stdout if containers[:lxc][:host]
    docker_containers = shell_out(docker_command).stdout if containers[:docker][:host]


    #Loop through our LXC containers and collect data on them
    lxc_containers.split(' ').each do |container|

      #Create a new mash if not there
      containers[:lxc][:container]["#{container}".to_sym] = Mash.new unless containers[:lxc][:container]["#{container}".to_sym]

      #Populate our container information
      populate_lxc_container(container)

    end if containers[:lxc][:host]


    #Loop through our Docker containers and collect data on them
    docker_containers.split(' ').each do |container|

      #Create a new mash if not there
      containers[:docker][:container]["#{container}".to_sym] = Mash.new unless containers[:docker][:container]["#{container}".to_sym]

      #Populate our container information
      populate_docker_container(container)

    end if containers[:docker][:host]

  end

  #Go through each container and populate the data
  def populate_lxc_container(container)

    command = "lxc-info -n #{ container }"

    #containers[:lxc][:container][container.to_s.to_sym][:tmp] = shell_out(command).stdout
    container_info = shell_out(command).stdout.split("\n")
    container_info.each do |line|

      #Seperate our attribute and value
      resp = line.split(":")

      #Set our attribute vlaue
      containers[:lxc][:container][container.to_s.to_sym][resp[0].to_s.strip().gsub(' ', '_').downcase().to_sym] = resp[1].to_s.strip()

    end

  end

  #Go through each docker container and populate the data
  def populate_docker_container(container)


  end

end