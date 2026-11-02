#!/usr/bin/env ruby

require "fileutils"
require "xcodeproj"

project_root = File.expand_path("..", __dir__)
project_path = File.join(project_root, "build", "ios", "PringgadaniFortress.xcodeproj")
app_dir = File.join(project_root, "build", "ios", "PringgadaniFortress")
storyboard_source = File.join(project_root, "ios", "Launch Screen.storyboard")
imageset_source = File.join(project_root, "ios", "SplashImage.imageset")
imageset_destination = File.join(app_dir, "Images.xcassets", "SplashImage.imageset")

abort "Missing exported Xcode project: #{project_path}" unless Dir.exist?(project_path)
abort "Missing launch storyboard source: #{storyboard_source}" unless File.file?(storyboard_source)
abort "Missing splash image set source: #{imageset_source}" unless Dir.exist?(imageset_source)

FileUtils.cp(storyboard_source, File.join(app_dir, "Launch Screen.storyboard"))
FileUtils.mkdir_p(imageset_destination)
FileUtils.cp(File.join(imageset_source, "Contents.json"), imageset_destination)

source_image = File.join(project_root, "assets", "dgs_boot_screen.png")
abort "Missing splash image: #{source_image}" unless File.file?(source_image)

%w[splash@2x.png splash@3x.png].each do |filename|
  FileUtils.cp(source_image, File.join(imageset_destination, filename))
end

project = Xcodeproj::Project.open(project_path)
target = project.targets.find { |candidate| candidate.name == "PringgadaniFortress" }
abort "PringgadaniFortress target not found in #{project_path}" unless target

app_group = project.main_group.groups.find { |group| group.path.to_s == "PringgadaniFortress" }
abort "PringgadaniFortress group not found in #{project_path}" unless app_group

storyboard_ref = app_group.files.find { |file| file.path.to_s == "Launch Screen.storyboard" }
storyboard_ref ||= app_group.new_file("Launch Screen.storyboard")

resources_phase = target.resources_build_phase
unless resources_phase.files.any? { |build_file| build_file.file_ref == storyboard_ref }
  resources_phase.add_file_reference(storyboard_ref)
end

project.build_configurations.each do |configuration|
  configuration.build_settings["INFOPLIST_KEY_UILaunchStoryboardName"] = "Launch Screen"
end
target.build_configurations.each do |configuration|
  configuration.build_settings["INFOPLIST_KEY_UILaunchStoryboardName"] = "Launch Screen"
end

project.save
