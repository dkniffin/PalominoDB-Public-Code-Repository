# 006_create_schema_tables.rb
# Copyright (C) 2009-2013 PalominoDB, Inc.
# 
# You may contact the maintainers at eng@palominodb.com.
# 
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 2 of the License, or
# (at your option) any later version.
# 
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
# 
# You should have received a copy of the GNU General Public License along
# with this program; if not, write to the Free Software Foundation, Inc.,
# 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA.

require 'rubygems'
require 'active_record'
require 'ttt/db'
require 'ttt/server'

class CreateSchemaTables < ActiveRecord::Migration
  def self.up
    create_table :servers do |st|
      st.string :name, :limit => 100, :null => false
      st.integer :cached_size
      st.timestamps
    end
    create_table :server_schemas do |s|
      s.string :name, :limit => 64, :null => false
      s.integer :server_id
      s.integer :cached_size
      s.timestamps
    end
    create_table :database_tables do |t|
      t.string :name, :limit => 64, :null => false
      t.integer :schema_id
      t.integer :cached_size
      t.timestamps
    end
    add_index :servers, :name, :unique
    add_index :server_schemas, :name
    add_index :database_tables, :name
    [TTT::TableVolume.all, TTT::TableDefinition.all, TTT::TableView.all].flatten.each do |s|
      srv=TTT::Server.find_or_create_by_name(:name => s.server)
      db=nil
      unless s.database_name.nil?
        db=srv.schemas.find_or_create_by_name(:name => s.database_name)
      end
      unless db.nil? and s.table_name.nil?
        db.tables.find_or_create_by_name(:name => s.table_name)
      end
    end
  end

  def self.down
    drop_table :servers
    drop_table :server_schemas
    drop_table :database_tables
  end
end
