#!/usr/bin/env ruby

require 'Spreadsheet'

class String
  def to_sql_col!
    gsub!(/\n/, ' ')
    gsub!(/\//, ' ')
    gsub!(/&/, 'and')
    gsub!(/\./, '')
    gsub!(/\-/, '_')
    downcase!
    gsub!(/\s+/, '_')
  end
end

class Float
  def prettify
    to_i == self ? to_i : self
  end
end

class Spreadsheet::Format
  FORMATS = {
    'GENERAL' => :string,
    '0' => :float,
    '0.00' => :float,
    '#,##0' => :float,
    '#,##0.00' => :float,
    '0%' => :percentage,
    '0.00%' => :percentage,
    '0.00E+00' => :float,
    '# ?/?' => :float,
    '# ??/??' => :float,
    'mm-dd-yy' => :date,
    'd-mmm-yy' => :date,
    'd-mmm' => :date,
    'mmm-yy' => :date,
    'h:mm AM/PM' => :date,
    'h:mm:ss AM/PM' => :date,
    'h:mm' => :time,
    'h:mm:ss' => :time,
    'm/d/yy h:mm' => :date,
    '#,##0 ;(#,##0)' => :float,
    '#,##0 ;[Red](#,##0)' => :float,
    '#,##0.00;(#,##0.00)' => :float,
    '#,##0.00;[Red](#,##0.00)' => :float,
    'mm:ss' => :time,
    '[h]:mm:ss' => :time,
    'mmss.0' => :time,
    '##0.0E+0' => :float,
    '@' => :float,
    "yyyy\\-mm\\-dd" => :date,
    'dd/mm/yy' => :date,
    'hh:mm:ss' => :time,
    "dd/mm/yy\\ hh:mm" => :datetime,
    "[<=9999999]###\\-####;\\(###\\)\\ ###\\-####" => :phone
  }

  STANDARD_FORMATS = {
    0 => 'GENERAL',
    1 => '0',
    2 => '0.00',
    3 => '#,##0',
    4 => '#,##0.00',
    9 => '0%',
    10 => '0.00%',
    11 => '0.00E+00',
    12 => '# ?/?',
    13 => '# ??/??',
    14 => 'mm-dd-yy',
    15 => 'd-mmm-yy',
    16 => 'd-mmm',
    17 => 'mmm-yy',
    18 => 'h:mm AM/PM',
    19 => 'h:mm:ss AM/PM',
    20 => 'h:mm',
    21 => 'h:mm:ss',
    22 => 'm/d/yy h:mm',
    37 => '#,##0 ;(#,##0)',
    38 => '#,##0 ;[Red](#,##0)',
    39 => '#,##0.00;(#,##0.00)',
    40 => '#,##0.00;[Red](#,##0.00)',
    45 => 'mm:ss',
    46 => '[h]:mm:ss',
    47 => 'mmss.0',
    48 => '##0.0E+0',
    49 => '@',
  }

  def cell_type
    format = :string
    format = FORMATS[self.number_format] if FORMATS.key?(self.number_format)
  end
end

book = Spreadsheet.open('/Users/jwinn/Desktop/2011_Marinedex_Master_Ready_for_Print_Oct_2011.xls')

sql = String.new

# parse each worksheet as new table
book.worksheets.each do |sheet|
  table_name = sheet.name.dup.to_s
  sql_col = []

  # generate table name
  sql << 'CREATE TABLE '
  sql << '"' << table_name.to_sql_col! << '"'
  sql << " (\n"

  # parse the first row column headers as table columns
  header = sheet.row(0)
  header.each_with_index do |h, i|
    cell = sheet.row(1)[i]
    cell_type = sheet.row(1).format(i).cell_type
    unless h.nil?
      h.to_sql_col!
      sql_col.push("\"#{h}\"")
      sql << "\t\"" << h << '"'
      sql << " VARCHAR(128)" if cell_type == :string
      sql << " VARCHAR(32)" if cell_type == :phone
      sql << " INT" if cell_type == :float && cell.prettify.to_s != cell.to_s
      sql << " FLOAT" if cell_type == :float && cell.prettify.to_s == cell.to_s
      sql << ',' if i < (header.length - 1)
      sql << "\n"
    end
  end

  sql << ");\n"

  sheet.each_with_index 1 do |row, i|
    # cleanup too many or too few rows compared to headers
    row.push(nil) if row.length < sql_col.length
    row.slice!(sql_col.length..row.length) if row.length > sql_col.length

    # check if empty row
    has_data = false
    row.each do |r|
      unless r.nil?
        has_data = true
        break
      end
    end

    if has_data
      sql << 'INSERT INTO ' << table_name
      sql << ' (' << sql_col.join(', ') << ') VALUES ('
      row.each_with_index do |col, c|
        cell_type = row.format(c).cell_type

        if col.nil?
          sql << 'NULL'
        elsif col.is_a?(Float)
          if cell_type == :float || cell_type == :percentage
            sql << col.prettify.to_s
          else
            sql << "'" << col.prettify.to_s << "'"
          end
        elsif col.is_a?(String)
          sql << "'" << col.gsub(/[^']'/, "''") << "'"
        end

        sql << ',' if c < (row.length - 1)
      end
      sql << ");\n"
    end

  end
end
puts sql
