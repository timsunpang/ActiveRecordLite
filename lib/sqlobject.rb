require_relative 'db_connection'
require_relative 'searchable'
require_relative 'associatable'
require 'active_support/inflector'

class SQLObject
  extend Searchable
  extend Associatable

  def self.columns
    @columns ||= DBConnection.execute2(<<-SQL)
      SELECT
        *
      FROM
        '#{table_name}'
    SQL

    @columns.first.map {|column| column.to_sym}
  end

  def self.finalize!
    columns.each do |column|

      define_method("#{column}") do
        attributes[column]
      end

      define_method("#{column}=") do |val|
        attributes[column] = val
      end
    end
  end

  def self.table_name=(table_name)
    @name = table_name
  end

  def self.table_name
    @name ||= self.to_s.tableize
    @name
  end

  def self.all
    results = DBConnection.execute(<<-SQL)
      SELECT
        #{table_name}.*
      FROM
        '#{table_name}'
    SQL
    parse_all(results)
  end

  def self.parse_all(results)
    results.map do |result|
      self.new(result)
    end
  end

  def self.find(id)
    result = DBConnection.execute(<<-SQL)
      SELECT
        #{table_name}.*
      FROM
        #{table_name}
      WHERE
        id = #{id}
    SQL

    parse_all(result).first
  end

  def initialize(params = {})
    params.each do |attr_name, value|
      attr_name = attr_name.to_sym
      unless self.class.columns.include? (attr_name)
        raise "unknown attribute '#{attr_name}'"
      else
        self.send("#{attr_name}=", value)
      end
    end
  end

  def attributes
    @attributes ||= Hash.new(nil)
    @attributes
  end

  def attribute_values
    @attributes.values
  end

  def insert
    col_names = self.class.columns.drop(1).join(", ")
    question_marks = self.class.columns.drop(1).map {|col| col = "?"}.join(", ")

    DBConnection.execute(<<-SQL, *attribute_values)
      INSERT INTO #{self.class.table_name} (#{col_names})
      VALUES (#{question_marks})
    SQL

    self.id = DBConnection.last_insert_row_id
  end

  def update
    set_line = self.class.columns.map {|attr_name| "#{attr_name} = ?"}.join(", ")

    DBConnection.execute(<<-SQL, *attribute_values, id)
      UPDATE #{self.class.table_name}
      SET #{set_line}
      WHERE #{self.class.table_name}.id = ?
    SQL
  end

  def save
    id.nil? ? insert : update
  end
end
