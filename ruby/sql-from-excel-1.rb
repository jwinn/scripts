#!/usr/bin/env ruby

require 'iconv'
require 'roo'

class String
  def to_sql_col!
    gsub!(/\n/, ' ')
    gsub!(/\//, ' ')
    gsub!(/&/, 'and')
    gsub!(/\./, '')
    downcase!
    gsub!(/\s+/, '_')
  end
end

class Float
  def prettify
    to_i == self ? to_i : self
  end
end

book = Excel.new('/Users/jwinn/Desktop/2011_Marinedex_Master_Ready_for_Print_Oct_2011.xls')

sql = ''

# parse each worksheet as new table
book.sheets.each do |sheet|
  book.default_sheet = sheet
  table_name = sheet.clone.to_s
  sql_col = []

  # generate table name
  sql << "CREATE TABLE "
  sql << table_name.to_sql_col!
  sql << " IF NOT EXISTS (\n"

  # parse the first row column headers as table columns
  header = book.row(book.first_row)
  header.each_with_index do |h, i|
    unless h.nil?
      h.to_sql_col!
      sql_col.push(h)
      sql << "\t" << h
      sql << "," if i < (header.count - 1)
      sql << "\n"
    end
  end

  sql << ");\n"

  2.upto(book.last_row) do |row|
    sql << "INSERT INTO " << table_name
    sql << " (" << sql_col.join(', ') << ") VALUES ("
    1.upto(book.last_column) do |col|
      cell_type = book.celltype(row, col)
      sql << book.cell(row, col).to_s if cell_type == :float
      sql << "'" << book.cell(row, col).encode('UTF-8') << "'" if cell_type == :string
      sql << "," if col < book.last_column
    end
    sql << ");\n"

  end
end
puts sql
