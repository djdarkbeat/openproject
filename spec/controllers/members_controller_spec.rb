#-- copyright
# OpenProject is a project management system.
# Copyright (C) 2012-2013 the OpenProject Foundation (OPF)
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License version 3.
#
# OpenProject is a fork of ChiliProject, which is a fork of Redmine. The copyright follows:
# Copyright (C) 2006-2013 Jean-Philippe Lang
# Copyright (C) 2010-2013 the ChiliProject Team
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.
#
# See doc/COPYRIGHT.rdoc for more details.
#++

require 'spec_helper'

describe MembersController do
  let(:admin) {FactoryGirl.create(:admin)}
  let(:user) { FactoryGirl.create(:user) }
  let(:project) { FactoryGirl.create(:project) }
  let(:role) { FactoryGirl.create(:role) }
  let(:member) { FactoryGirl.create(:member, :project => project,
                                             :user => user,
                                             :roles => [role]) }

  before do
    User.stub(:current).and_return(admin)
  end

  describe :autocomplete_for_member do
    let(:params) { ActionController::Parameters.new({ "id" => project.identifier.to_s }) }

    before do
      User.stub(:current).and_return(user)
    end

    describe "WHEN the user is authorized
              WHEN a project is provided" do
      before do
        role.permissions << :manage_members
        role.save!
        member
      end

      it "should be success" do
        post :autocomplete_for_member, params, :format => :xhr
        response.should be_success
      end
    end

    describe "WHEN the user is not authorized" do
      it "should be forbidden" do
        post :autocomplete_for_member, params, :format => :xhr
        response.response_code.should == 403
      end
    end
  end

  describe :create do
    render_views
    let(:user2) { FactoryGirl.create(:user) }
    let(:user3) { FactoryGirl.create(:user) }
    let(:user4) { FactoryGirl.create(:user) }
    let(:valid_params) { { :format => "js",
                         :project_id => project.id,
                         :member => {:role_ids => [role.id],
                                     :user_ids => [user2.id, user3.id, user4.id]}}
                        }
    let(:invalid_params) { { :format => "js",
                           :project_id => project.id,
                           :member => {:role_ids => [],
                                       :user_ids => [user2.id, user3.id, user4.id]}}
                          }

    context "post :create" do
      context "single member" do
        let(:action) { post :create, :project_id => project.id, :member => {:role_ids => [role.id], :user_id => user2.id} }

        it "should add a member" do
          expect{action}.to change {Member.count}.by(1)
          expect(response).to redirect_to(settings_project_path(project)+'/members')
          expect(user2).to be_member_of(project)
        end
      end

      context "multiple members" do
        let(:action) { post :create, :project_id => project.id, :member => {:role_ids => [role.id], :user_ids => [user2.id, user3.id, user4.id] } }

        it "should add all members" do
          expect{action}.to change {Member.count}.by(3)
          expect(response).to redirect_to(settings_project_path(project)+'/members')
          expect(user2).to be_member_of(project)
          expect(user3).to be_member_of(project)
          expect(user4).to be_member_of(project)
        end
      end
    end

    context "post :create in JS format" do
      context "with successful saves" do
        before do
          post :create, valid_params
        end

        it "should add members" do
          user2.should be_member_of(project)
          user3.should be_member_of(project)
          user4.should be_member_of(project)
        end

        it "should replace the tab with RJS" do
          assert_select_rjs :replace_html, 'tab-content-members'
        end
      end
    end

    context "with a failed save" do
      it "should not replace the tab with RJS" do
        post :create, invalid_params
        assert_select '#tab-content-members', 0
      end

      it "should show an error message" do
        post :create, invalid_params

        assert_select_rjs :insert_html, :top do
          assert_select '#errorExplanation'
        end
      end
    end
  end

  describe :destroy do
    let(:action) { post :destroy, :id => member.id }
    before do
      member
    end

    it "should destroy a member" do
      expect{action}.to change {Member.count}.by(-1)
      expect(response).to redirect_to(settings_project_path(project)+'/members')
      expect(user).to_not be_member_of(project)
    end
  end

  describe :update do
    let(:action) { post :update, :id => member.id, :member => {:role_ids => [role2.id], :user_id => user.id} }
    let(:role2) { FactoryGirl.create(:role) }

    before do
      member
    end

    it "should update the member" do
      expect{action}.to_not change {Member.count}
      expect(response).to redirect_to(settings_project_path(project)+'/members')
    end
  end
end
