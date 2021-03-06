require 'axlsx'
require 'axlsx_styler'

require 'spreadsheet_architect/monkey_patches/axlsx_column_width'

module SpreadsheetArchitect
  module ClassMethods
    def to_xlsx(opts={})
      return to_axlsx_package(opts).to_stream.read
    end

    def to_axlsx_package(opts={}, package=nil)
      opts = SpreadsheetArchitect::Utils.get_cell_data(opts, self)
      options = SpreadsheetArchitect::Utils.get_options(opts, self)
    
      header_style = SpreadsheetArchitect::Utils::XLSX.convert_styles_to_axlsx(options[:header_style])
      row_style = SpreadsheetArchitect::Utils::XLSX.convert_styles_to_axlsx(options[:row_style])

      if package.nil?
        package = Axlsx::Package.new
      end

      return package if !options[:headers] && options[:data].empty?

      package.workbook.add_worksheet(name: options[:sheet_name]) do |sheet|
        max_row_length = options[:data].empty? ? 0 : options[:data].max_by{|x| x.length}.length

        if options[:headers]
          header_style_index = package.workbook.styles.add_style(header_style)

          options[:headers].each do |header_row|
            missing = max_row_length - header_row.count
            if missing > 0
              missing.times do
                header_row.push(nil)
              end
            end

            sheet.add_row header_row, style: header_style_index
          end
        end

        if options[:data].empty?
          break
        end

        row_style_index = package.workbook.styles.add_style(row_style)

        options[:data].each do |row_data|
          missing = max_row_length - row_data.count
          if missing > 0
            missing.times do
              row_data.push(nil)
            end
          end

          types = []
          row_data.each_with_index do |x,i|
            if (x.respond_to?(:empty) ? x.empty? : x.nil?)
              types[i] = nil
            else
              if options[:column_types]
                types[i] = options[:column_types][i]
              end

              types[i] ||= SpreadsheetArchitect::Utils::XLSX.get_type(x)
            end
          end

          sheet.add_row row_data, style: row_style_index, types: types
        end

        options[:data].first.each_with_index do |x,i|
          types = []

          if options[:column_types]
            types[i] = options[:column_types][i]
          end

          types[i] ||= SpreadsheetArchitect::Utils::XLSX.get_type(x)

          if [:date, :time].include?(types[i])
            if types[i] == :date
              format_code = 'm/d/yyyy'
            else
              format_code = 'yyyy/m/d h:mm AM/PM'
            end

            sheet.col_style(i, package.workbook.styles.add_style(format_code: format_code), row_offset: (options[:headers] ? options[:headers].count : 0))
          end
        end

        if options[:column_widths]
          sheet.column_widths(*options[:column_widths])
        end

        if options[:borders] || options[:column_styles] || options[:range_styles] || options[:merges]
          col_names = max_row_length > 675 ? Array('A'..'ZZZ') : Array('A'..'ZZ')
          num_rows = options[:data].count + (options[:headers] ? options[:headers].count : 0)
        end

        if options[:borders]
          options[:borders].each do |x|
            if x[:range].is_a?(Hash)
              x[:range] = SpreadsheetArchitect::Utils::XLSX.range_hash_to_str(x[:range], max_row_length, num_rows, col_names)
            end

            SpreadsheetArchitect::Utils::XLSX.verify_range(x[:range], num_rows, col_names)
            sheet.add_border x[:range], x[:border_styles]
          end
        end

        if options[:column_styles]
          options[:column_styles].each do |x|
            start_row = options[:headers] ? options[:headers].count : 0

            if x[:include_header] && start_row > 0
              h_style = header_style.merge(SpreadsheetArchitect::Utils::XLSX.convert_styles_to_axlsx(x[:styles]))
            end

            package.workbook.styles do |s|
              style = s.add_style row_style.merge(SpreadsheetArchitect::Utils::XLSX.convert_styles_to_axlsx(x[:styles]))

              if x[:columns].is_a?(Array) || x[:columns].is_a?(Range) 
                x[:columns].each do |col|
                  if col.is_a?(String)
                    col = col_names.index(col)
                  end

                  if col.is_a?(Integer) && col < max_row_length
                    sheet.col_style(col, style, row_offset: start_row)

                    if h_style
                      sheet.add_style("#{col_names[col]}1:#{col_names[col]}#{start_row}", h_style)
                    end
                  else
                    raise SpreadsheetArchitect::Exceptions::InvalidColumnError
                  end
                end
              elsif x[:columns].is_a?(Integer)
                col = x[:columns]
                if col < max_row_length
                  sheet.col_style(x[:columns], style, row_offset: start_row)

                  if h_style
                    sheet.add_style("#{col_names[col]}1:#{col_names[col]}#{start_row}", h_style)
                  end
                else
                  raise SpreadsheetArchitect::Exceptions::InvalidColumnError
                end
              end
            end
          end
        end

        if options[:range_styles]
          options[:range_styles].each do |x|
            styles = SpreadsheetArchitect::Utils::XLSX.convert_styles_to_axlsx(x[:styles])

            if x[:range].is_a?(Hash)
              x[:range] = SpreadsheetArchitect::Utils::XLSX.range_hash_to_str(x[:range], max_row_length, num_rows, col_names)
            end

            SpreadsheetArchitect::Utils::XLSX.verify_range(x[:range], num_rows, col_names)
            sheet.add_style x[:range], styles
          end
        end

        if options[:merges]
          options[:merges].each do |x|
            if x[:range].is_a?(Hash)
              x[:range] = SpreadsheetArchitect::Utils::XLSX.range_hash_to_str(x[:range], max_row_length, num_rows, col_names)
            end

            SpreadsheetArchitect::Utils::XLSX.verify_range(x[:range], num_rows, col_names)
            sheet.merge_cells x[:range]
          end
        end
      end

      return package
    end
  end
end
