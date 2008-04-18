require File.dirname(__FILE__) + '/../../spec_helper'

# set up a few test classes to make sure all the different types of model names work
# properly (e.g. weird pluralisations, multi-word models etc)
class Admin::FlangesController        < Admin::CrudController; end
class Admin::StrangeRabbitsController < Admin::CrudController; end

class Flange < ActiveRecord::Base; end
class StrangeRabbit < ActiveRecord::Base; end

['Flanges', 'StrangeRabbits'].each do |class_name|
  describe "CRUD controllers" do
    controller_name "Admin::#{class_name}"
    
    before(:each) do
      login_as_admin
      
      @site = mock_model(Site, :id => 1)
      Site.stub!(:find_active_by_hostname).and_return(@site)
      
      # set up the variables we'll refer to in all specs below.
      # If we had an AssetsController, these would map to:
      # @model_name                    => 'Asset'
      # @model_klass                   => Asset
      # @model_symbol                  => :Asset
      # @pluralized_model_name         => 'Assets'
      # @assigns_model_name            => :asset
      # @pluralized_assigns_model_name => :assets
      @model_name                    = class_name.classify
      @model_klass                   = @model_name.constantize
      @model_symbol                  = @model_name.to_sym
      @pluralized_model_name         = @model_name.humanize.pluralize
      @assigns_model_name            = @model_name.underscore.to_sym
      @pluralized_assigns_model_name = @model_name.underscore.pluralize.to_sym
      
      # continuing AssetsController example, this maps to:
      # @stubbed_model => mock_model(Asset, :id => 1)
      # @stubbed_model_collection => [@stubbed_model]
      # Asset.stub!(:find).and_return(@stubbed_model_collection)
      @stubbed_model = mock_model(@model_klass, :id => 1, :to_xml => 'XML', :to_ext_json => 'JSON', :site= => true)
      @stubbed_model_collection = [@stubbed_model]
      @model_klass.stub!(:find).with(:all).and_return(@stubbed_model_collection)
      
      # e.g. Asset.stub!(:count).and_return(@count)
      @count = 10
      @model_klass.stub!(:count).and_return(@count)
    end
    
    # TODO: this currently gets repeated, move it out of here
    describe "when initialising class" do      
      before(:each) do
        @basic_controller = Admin::FlangesController.new
        @multiword_controller = Admin::StrangeRabbitsController.new
      end
      
      it "should find the correct model name" do
        @basic_controller.model_name.should == 'Flange'
        @multiword_controller.model_name.should == "StrangeRabbit"
      end
      
      it "should find the correct model class" do
        @basic_controller.model_klass.should == Flange
        @multiword_controller.model_klass.should == StrangeRabbit
      end
      
      it "should find the correct model symbol" do
        @basic_controller.model_symbol.should == :Flange
        @multiword_controller.model_symbol.should == :StrangeRabbit
      end
    end
    
    describe "GET index" do
      it "should find all #{@pluralized_model_name}" do
        @model_klass.should_receive(:find).with(:all)
        do_get
      end
      
      it "should be successful" do
        do_get
        response.should be_success
      end
      
      it "should render the correct template" do
        do_get
        response.should render_template(:index)    
      end
      
      it "should render the correct xml" do
        @stubbed_model_collection.should_receive(:to_xml).and_return('XML')
        do_get nil, 'xml'
        response.body.should == 'XML'
      end
      
      it "should render JSON when calling index.ext_json" do
        @stubbed_model_collection.should_receive(:to_ext_json).and_return('JSON')
        do_get nil, 'ext_json'
        response.body.should == 'JSON'
      end
      
      it "should assign the #{@pluralized_model_name} to the #{@pluralized_model_name} view variable" do
        do_get
        assigns[@pluralized_assigns_model_name].should == @stubbed_model_collection
      end

      def do_get page = nil, format = 'html'
        get 'index', :format => format
      end
    end
    
    describe "GET show with a valid ID" do
      before(:each) do
        @model_klass.stub!(:find).and_return(@stubbed_model)
      end
      
      it "should find the correct #{@model_name}" do
        @model_klass.should_receive(:find).with(@stubbed_model.id.to_s).and_return(@stubbed_model)
        do_get
      end
      
      it "should render the correct template when requesting HTML" do
        do_get
        response.should render_template(:show)
      end
      
      it "should render the correct XML when requesting XML" do
        @stubbed_model.should_receive(:to_xml).and_return('XML')    
        do_get 'xml'
        response.body.should == 'XML'
      end
      
      # TODO: figure out why this doesn't work (gives CircularReferenceError)
      # it "should render the correct JSON when requesting EXT" do
      #   Array.should_receive(:to_ext_json).with(@stubbed_model).and_return('EXT')
      #   do_get 'ext_json'
      #   response.body.should == 'EXT'
      # end
      
      def do_get format = 'html'
        get 'show', :id => @stubbed_model.id, :format => format
      end
    end
    
    describe "GET show with an invalid ID" do
      before(:each) do
        @model_klass.stub!(:find).and_raise(ActiveRecord::RecordNotFound)
      end
      
      it "should redirect to /admin if not found via HTML" do
        do_get
        response.should redirect_to("/admin/#{@pluralized_assigns_model_name}")
      end
      
      it "should send a 404 if not found via XML" do
        do_get 'xml'
        response.headers["Status"].should == "404 Not Found"
      end
      
      it "should render success: false via EXT" do
        do_get 'ext_json'
        response.body.should == "{success: false}"
      end
      
      def do_get format = 'html'
        get 'show', :id => -1, :format => format
      end
    end

    describe "POST create with valid params" do
      
      before(:each) do
        @new_stubbed_model = mock_model(@model_klass, :id => 1, :save => true, :image? => false, :site= => true)
        @new_stubbed_model.stub!(:to_ext_json).and_return("{success: true, data: ext}")
        @model_klass.stub!(:new).and_return(@new_stubbed_model)
        
        @params = {"title" => 'test', "key" => "value"}
      end
      
      it "should build a new #{@model_name}" do
        @model_klass.should_receive(:new).with(@params).and_return(@new_stubbed_model)
        do_post
      end
  
      it "should save the #{@model_name}" do
        @new_stubbed_model.should_receive(:save).and_return(true)
        do_post
      end
      
      it "should redirect to the new #{@model_name}'s show page when requesting HTML" do
        do_post
        response.should redirect_to("/admin/#{@pluralized_assigns_model_name}/edit/#{@new_stubbed_model.id}")
      end
      
      it "should set the current site as the #{@model_name}'s site" do
        @new_stubbed_model.should_receive(:site=).with(@site).and_return(true)
        do_post
      end
      
      it "should render success: true when requesting EXT" do
        @new_stubbed_model.should_receive(:to_ext_json).and_return('ext')
        
        do_post 'ext_json'
        response.body.should == "ext"
      end
      
      it "should return .to_xml when requesting XML" do
        @new_stubbed_model.should_receive(:to_xml).and_return('XML')
        do_post 'xml'
        response.body.should == "XML"
      end
      
      def do_post format = 'html'
        post 'create', @assigns_model_name => @params, :format => format
      end
    end

    describe "POST create with invalid parameters" do
      before(:each) do
        @errors = mock_model(Array, :collect => [], :full_messages => [], :add => true, :to_xml => 'XML')
        
        @new_stubbed_model = mock_model(@model_klass, :id => 1, :save => true, :image? => false, :site= => true, :errors => @errors)
        @new_stubbed_model.stub!(:to_ext_json).and_return("{success: false, errors: {}}")
        @new_stubbed_model.stub!(:save).and_return(false)
        @model_klass.stub!(:new).and_return(@new_stubbed_model)
        
        @params = {"title" => 'test', "key" => "value"}
      end
      
      it "should render the new template when requesting HTML" do
        do_post
        response.should render_template(:new)    
      end
      
      it "should render the errors to XML when requesting XML" do
        @errors.should_receive(:to_xml).and_return('XML')
        
        do_post 'xml'
        response.body.should == 'XML'
      end
      
      it "should render success: false when requesting EXT" do
        do_post 'ext_json'
        response.body.should == '{success: false, errors: {}}'
      end
      
      def do_post format = 'html'
        post 'create', @assigns_model_name => @params, :format => format
      end
    end
    
    describe "PUT update with valid parameters" do
      
      before(:each) do
        @stubbed_model.stub!(:update_attributes).and_return(true)
        
        @model_klass.stub!(:find).and_return(@stubbed_model)
      end
      
      it "should find the #{@model_name}" do
        @model_klass.should_receive(:find).with(@stubbed_model.id.to_s).and_return(@stubbed_model)
        do_put
      end
      
      it "should save the #{@model_name}" do
        @stubbed_model.should_receive(:update_attributes).with({"title" => 'test'}).and_return(true)
        do_put
      end
      
      it "should redirect to the index path when requesting HTML" do
        do_put
        response.should redirect_to("/admin/#{@pluralized_assigns_model_name}")
        flash[:notice].should_not be(nil)
      end
      
      it "should render success: true when requesting EXT" do
        do_put 'ext_json'
        response.body.should == @stubbed_model.to_ext_json
      end
      
      it "should render 200 OK for XML" do
        do_put 'xml'
        response.headers["Status"].should == "200 OK"
      end
        
      def do_put format = 'html'
        put 'update', :id => @stubbed_model.id, @assigns_model_name => {:title => 'test'}, :format => format
      end
    end

    describe "PUT update with invalid parameters" do
      before(:each) do
        @errors = mock_model(Array, :full_messages => [], :collect => [], :to_xml => 'XML')
        @stubbed_model.stub!(:errors).and_return(@errors)
        @stubbed_model.stub!(:update_attributes).and_return(false)
        
        @model_klass.stub!(:find).and_return(@stubbed_model)
      end
      
      it "should redirect to the #{@model_name} index if the #{@model_name} was not found" do
        @model_klass.should_receive(:find).and_raise(ActiveRecord::RecordNotFound)
        do_put
        
        response.should redirect_to("/admin/#{@pluralized_assigns_model_name}")    
      end
      
      it "should render the edit action when requesting with HTML" do
        do_put
        response.should render_template(:edit)    
      end
      
      it "should render success: false when requesting with EXT" do
        do_put 'ext_json'
        response.body.should == "{success: false}"
      end
      
      it "should render the errors to XML when requesting with XML" do  
        @errors.should_receive(:to_xml).and_return('XML')
            
        do_put 'xml'
        response.body.should == 'XML'
      end
      
      def do_put format = 'html'
        put 'update', :id => @stubbed_model.id, @model_symbol => {}, :format => format
      end
    end
    
    describe "DELETE destroy with a valid id" do
      
      before(:each) do
        @stubbed_model.stub!(:destroy).and_return(true)
        @model_klass.stub!(:find).and_return(@stubbed_model)
      end
      
      it "should find the correct #{@model_name}" do
        @model_klass.should_receive(:find).with(@stubbed_model.id.to_s).and_return(@stubbed_model)
        do_delete
      end
      
      it "should destroy the #{@model_name}" do
        @stubbed_model.should_receive(:destroy).and_return(true)    
        do_delete
      end
      
      it "should redirect to #{@model_name} index when requesting HTML" do
        do_delete
        response.should redirect_to("/admin/#{@pluralized_assigns_model_name}")
      end
      
      it "should return success when requesting EXT" do
        do_delete 'ext_json'
        response.body.should == "{success: true}"
      end
      
      it "should render 200 when requesting XML" do
        do_delete 'xml'
        response.headers["Status"].should == "200 OK"
      end
      
      def do_delete format = 'html'
        delete 'destroy', :id => @stubbed_model.id, :format => format
      end
    end
    
    describe "DELETE destroy with an invalid ID" do
      
      before(:each) do
        @model_klass.stub!(:find).and_raise(ActiveRecord::RecordNotFound)
      end
      
      it "should redirect to #{@model_name} index when requesting HTML" do
        do_delete
        response.should redirect_to("/admin/#{@pluralized_assigns_model_name}")    
      end
      
      it "should render a 404 when requesting XML" do
        do_delete 'xml'
        response.headers["Status"].should == "404 Not Found"
      end
      
      it "should render success: false when requesting EXT" do
        do_delete 'ext_json'
        response.body.should == "{success: false}"
      end
      
      def do_delete format = 'html'
        delete 'destroy', :id => -1, :format => format
      end
    end
    
    describe "GET edit with a valid ID" do
      before(:each) do
        @model_klass.stub!(:find).and_return(@stubbed_model)
      end
      
      it "should find the #{@model_name}" do
        @model_klass.should_receive(:find).with(@stubbed_model.id.to_s).and_return(@stubbed_model)
        do_get
      end
      
      it "should render the edit template when requesting HTML" do
        do_get
        response.should render_template(:edit)    
      end
      
      it "should be successful" do
        do_get
        response.should be_success
      end
      
      def do_get format = 'html'
        get 'edit', :id => @stubbed_model.id, :format => format
      end
    end
    
    describe "GET edit with an invalid ID" do
      before(:each) do
        @model_klass.stub!(:find).and_raise(ActiveRecord::RecordNotFound)
      end
      
      it "should redirect to the #{@model_name} index when requesting HTML" do
        do_get
        response.should redirect_to("/admin/#{@pluralized_assigns_model_name}")    
      end
      
      it "should render success: false when requesting EXT" do
        do_get 'ext_json'
        response.body.should == "{success: false}"
      end
      
      it "should render a 404 when requesting XML" do
        do_get 'xml'
        response.headers["Status"].should == "404 Not Found"
      end
      
      def do_get format = 'html'
        get 'edit', :id => -1, :format => format
      end
    end

  end
end
