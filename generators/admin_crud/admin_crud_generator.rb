class AdminCrudGenerator < Rails::Generator::Base
  def manifest 
    record do |m|
      m.directory("app/controllers/admin")
      m.directory("spec")
      m.directory("spec/controllers")
      m.directory("spec/controllers/admin")
      
      m.file("controllers/crud_controller.rb", "app/controllers/admin/crud_controller.rb")
      m.file("specs/crud_controller_spec.rb", "spec/admin/crud_controller_spec.rb")
      
      m.readme "../USAGE"
    end
  end
end