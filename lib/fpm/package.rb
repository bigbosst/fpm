require "fpm/namespace"
require "socket" # for Socket.gethostname

class FPM::Package 
  # The name of this package
  attr_accessor :name

  # The version of this package (the upstream version)
  attr_accessor :version

  # The iteration of this package.
  #   Debian calls this 'release' and is the last '-NUMBER' in the version
  #   RedHat has this as 'Release' in the .spec file
  #   FreeBSD calls this 'PORTREVISION' 
  # If left unpicked, it defaults to 1.
  attr_accessor :iteration

  # Who maintains this package? This could be the upstream author
  # or the package maintainer. You pick.
  attr_accessor :maintainer

  # URL for this package.
  # Could be the homepage. Could be the download url. You pick.
  attr_accessor :url

  # The category of this package.
  # RedHat calls this 'Group'
  # Debian calls this 'Section'
  # FreeBSD would put this in /usr/ports/<category>/...
  attr_accessor :category

  # A identifier representing the license. Any string is fine.
  attr_accessor :license

  # What architecture is this package for?
  attr_accessor :architecture

  # Array of dependencies.
  attr_accessor :dependencies
  
  def initialize
    @iteration = 1
    @url = "http://nourlgiven.example.com/no/url/given"
    @category = "default"
    @license = "unknown"
    @maintainer = "<#{ENV["USER"]}@#{Socket.gethostname}>"
    @architecture = nil
    @summary = "no summary given"

    # Garbage is stuff you may want to clean up.
    @garbage = []
  end

  # Assemble the package.
  # params:
  #  "root" => "/some/path"   # the 'root' of your package directory
  #  "paths" => [ "/some/path" ...]  # paths to icnlude in this package
  #  "output" => "foo.deb"  # what to output to.
  #
  # The 'output' file path will have 'VERSION' and 'ARCH' replaced with
  # the appropriate values if if you want the filename generated.
  def assemble(params)
    raise "No package name given. Can't assemble package" if !@name

    root = params["root"] || '.'
    paths = params["paths"]
    output = params["output"]

    output.gsub!(/VERSION/, "#{version}-#{iteration}")
    output.gsub!(/ARCH/, architecture)
    File.delete(output) if File.exists?(output)

    builddir = "#{Dir.pwd}/build-#{type}-#{File.basename(output)}"
    @garbage << builddir

    Dir.mkdir(builddir) if !File.directory?(builddir)

    Dir.chdir root do
      tar("#{builddir}/data.tar", paths)

      # TODO(sissel): Make a helper method.
      system(*["gzip", "-f", "#{builddir}/data.tar"])

      generate_md5sums(builddir, paths)
      generate_specfile(builddir, paths)
    end

    Dir.chdir(builddir) do
      build(params)
    end
  end # def assemble

  def generate_specfile(builddir, paths)
    spec = template.result(binding)
    File.open(specfile(builddir), "w") { |f| f.puts spec }
  end

  def generate_md5sums(builddir, paths)
    md5sums = self.checksum(paths)
    File.open("#{builddir}/md5sums", "w") { |f| f.puts md5sums }
    md5sums
  end

  def checksum(paths)
    md5sums = []
    paths.each do |path|
      md5sums += %x{find #{path} -type f -print0 | xargs -0 md5sum}.split("\n")
    end
  end # def checksum

  # TODO [Jay]: make this better...?
  def type
    self.class.name.split(':').last.downcase
  end

  def template
    @template ||= begin
      tpl = File.read(
        "#{File.dirname(__FILE__)}/../../templates/#{type}.erb"
      )
      ERB.new(tpl, nil, "<>")
    end
  end

end
