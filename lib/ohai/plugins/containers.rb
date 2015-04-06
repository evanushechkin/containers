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
    docker_command = "docker ps -a | awk {'print $1'}"

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
    docker_containers.split("\n").each do |container|

      unless container == 'CONTAINER'
        #Create a new mash if not there
        containers[:docker][:container]["#{container}".to_sym] = Mash.new unless containers[:docker][:container]["#{container}".to_sym]

        #Populate our container information
        populate_docker_container(container)
      end

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

    #We will grab our directories under /var/lib/docker
    ::Dir.glob('/var/lib/docker/containers/*/').each do |directory|

      #Set our base path to parse config json
      @config_file = "#{directory}config.json" if directory.to_s.include?(container)

    end

    #Parse the single line JSON configuration
    container_config = JSON.parse(File.readlines(@config_file).first.chomp)

    #Let's populate
    container_config.each do |k,v|

      if v.to_s.include?('{') && v.to_s.include?('}')

        #If we have a sub k/v then lets traverse
        populate_sub_mash(k,v,containers[:docker][:container]["#{container}".to_sym])

      else

        containers[:docker][:container]["#{container}".to_sym]["#{k}".to_sym] = v

      end

    end

  end

  #This Will Populate Sub Mashes
  def populate_sub_mash(k,v,base)

    #Create from base
    base["#{k}".to_sym] = Mash.new unless base["#{k}".to_sym]

    #Loop through those values
    v.each do  |sub_k,sub_v|

      #If we have another level, just keep calling until we reach the bottom
      if sub_v.to_s.include?('{') && sub_v.to_s.include?('}')

        populate_sub_mash(k,v,base["#{k}".to_sym])

      else

        #Or, we just finish up
        base["#{k}".to_sym]["#{sub_k}".to_sym] = sub_v

      end

    end

  end

end