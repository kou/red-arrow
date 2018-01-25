# Copyright 2017-2018 Kouhei Sutou <kou@clear-code.com>
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

class TableTest < Test::Unit::TestCase
  include Helper::Fixture

  def setup
    @count_field = Arrow::Field.new("count", :uint8)
    @visible_field = Arrow::Field.new("visible", :boolean)
    schema = Arrow::Schema.new([@count_field, @visible_field])
    count_arrays = [
      Arrow::UInt8Array.new([1, 2]),
      Arrow::UInt8Array.new([4, 8, 16]),
      Arrow::UInt8Array.new([32, 64]),
      Arrow::UInt8Array.new([128]),
    ]
    visible_arrays = [
      Arrow::BooleanArray.new([true, false, nil]),
      Arrow::BooleanArray.new([true]),
      Arrow::BooleanArray.new([true, false]),
      Arrow::BooleanArray.new([nil]),
      Arrow::BooleanArray.new([nil]),
    ]
    @count_array = Arrow::ChunkedArray.new(count_arrays)
    @visible_array = Arrow::ChunkedArray.new(visible_arrays)
    @count_column = Arrow::Column.new(@count_field, @count_array)
    @visible_column = Arrow::Column.new(@visible_field, @visible_array)
    @table = Arrow::Table.new(schema, [@count_column, @visible_column])
  end

  test("#columns") do
    assert_equal(["count", "visible"],
                 @table.columns.collect(&:name))
  end

  sub_test_case("#slice") do
    test("Arrow::BooleanArray") do
      target_rows_raw = [nil, true, true, false, true, false, true, true]
      target_rows = Arrow::BooleanArray.new(target_rows_raw)
      assert_equal(<<-TABLE, @table.slice(target_rows).to_s)
	count	visible
0	    2	false  
1	    4	       
2	   16	true   
3	   64	       
4	  128	       
      TABLE
    end

    test("Integer: positive") do
      assert_equal(<<-TABLE, @table.slice(2).to_s)
	count	visible
0	    4	       
      TABLE
    end

    test("Integer: negative") do
      assert_equal(<<-TABLE, @table.slice(-1).to_s)
	count	visible
0	  128	       
      TABLE
    end

    test("Range: positive: include end") do
      assert_equal(<<-TABLE, @table.slice(2..4).to_s)
	count	visible
0	    4	       
1	    8	true   
2	   16	true   
      TABLE
    end

    test("Range: positive: exclude end") do
      assert_equal(<<-TABLE, @table.slice(2...4).to_s)
	count	visible
0	    4	       
1	    8	true   
      TABLE
    end

    test("Range: negative: include end") do
      assert_equal(<<-TABLE, @table.slice(-4..-2).to_s)
	count	visible
0	   16	true   
1	   32	false  
2	   64	       
      TABLE
    end

    test("Range: negative: exclude end") do
      assert_equal(<<-TABLE, @table.slice(-4...-2).to_s)
	count	visible
0	   16	true   
1	   32	false  
      TABLE
    end

    test("[from, to]: positive") do
      assert_equal(<<-TABLE, @table.slice([0, 2]).to_s)
	count	visible
0	    1	true   
1	    2	false  
      TABLE
    end

    test("[from, to]: negative") do
      assert_equal(<<-TABLE, @table.slice([-4, 2]).to_s)
	count	visible
0	   16	true   
1	   32	false  
      TABLE
    end

    test("Integer, Range, ...") do
      assert_equal(<<-TABLE, @table.slice(0, 4...7).to_s)
	count	visible
0	    1	true   
1	   16	true   
2	   32	false  
3	   64	       
      TABLE
    end
  end

  sub_test_case("#[]") do
    test("[String]") do
      assert_equal(@count_column, @table["count"])
    end

    test("[Symbol]") do
      assert_equal(@visible_column, @table[:visible])
    end

    test("[String, Symbol]") do
      raw_table = {
        :a => Arrow::UInt8Array.new([1]),
        :b => Arrow::UInt8Array.new([1]),
        :c => Arrow::UInt8Array.new([1]),
        :d => Arrow::UInt8Array.new([1]),
        :e => Arrow::UInt8Array.new([1]),
      }
      table = Arrow::Table.new(raw_table)
      assert_equal(Arrow::Table.new(:c => raw_table[:c],
                                    :b => raw_table[:b]).to_s,
                   table["c", :b].to_s)
    end
  end

  sub_test_case("#merge") do
    sub_test_case("Hash") do
      test("add") do
        name_array = Arrow::StringArray.new(["a", "b", "c", "d", "e", "f", "g", "h"])
        assert_equal(<<-TABLE, @table.merge(:name => name_array).to_s)
	count	visible	name
0	    1	true   	a   
1	    2	false  	b   
2	    4	       	c   
3	    8	true   	d   
4	   16	true   	e   
5	   32	false  	f   
6	   64	       	g   
7	  128	       	h   
        TABLE
      end

      test("remove") do
        assert_equal(<<-TABLE, @table.merge(:visible => nil).to_s)
	count
0	    1
1	    2
2	    4
3	    8
4	   16
5	   32
6	   64
7	  128
        TABLE
      end

      test("replace") do
        visible_array = Arrow::Int32Array.new([1] * @visible_array.length)
        assert_equal(<<-TABLE, @table.merge(:visible => visible_array).to_s)
	count	visible
0	    1	      1
1	    2	      1
2	    4	      1
3	    8	      1
4	   16	      1
5	   32	      1
6	   64	      1
7	  128	      1
        TABLE
      end
    end

    sub_test_case("Arrow::Table") do
      test("add") do
        name_array = Arrow::StringArray.new(["a", "b", "c", "d", "e", "f", "g", "h"])
        table = Arrow::Table.new("name" => name_array)
        assert_equal(<<-TABLE, @table.merge(table).to_s)
	count	visible	name
0	    1	true   	a   
1	    2	false  	b   
2	    4	       	c   
3	    8	true   	d   
4	   16	true   	e   
5	   32	false  	f   
6	   64	       	g   
7	  128	       	h   
        TABLE
      end

      test("replace") do
        visible_array = Arrow::Int32Array.new([1] * @visible_array.length)
        table = Arrow::Table.new("visible" => visible_array)
        assert_equal(<<-TABLE, @table.merge(table).to_s)
	count	visible
0	    1	      1
1	    2	      1
2	    4	      1
3	    8	      1
4	   16	      1
5	   32	      1
6	   64	      1
7	  128	      1
        TABLE
      end
    end
  end

  test("column name getter") do
    assert_equal(@visible_column, @table.visible)
  end

  sub_test_case("#remove_column") do
    test("String") do
      assert_equal(<<-TABLE, @table.remove_column("visible").to_s)
	count
0	    1
1	    2
2	    4
3	    8
4	   16
5	   32
6	   64
7	  128
      TABLE
    end

    test("Symbol") do
      assert_equal(<<-TABLE, @table.remove_column(:visible).to_s)
	count
0	    1
1	    2
2	    4
3	    8
4	   16
5	   32
6	   64
7	  128
      TABLE
    end

    test("unknown column name") do
      assert_raise(KeyError) do
        @table.remove_column(:nonexistent)
      end
    end

    test("Integer") do
      assert_equal(<<-TABLE, @table.remove_column(1).to_s)
	count
0	    1
1	    2
2	    4
3	    8
4	   16
5	   32
6	   64
7	  128
      TABLE
    end

    test("negative integer") do
      assert_equal(<<-TABLE, @table.remove_column(-1).to_s)
	count
0	    1
1	    2
2	    4
3	    8
4	   16
5	   32
6	   64
7	  128
      TABLE
    end

    test("too small index") do
      assert_raise(IndexError) do
        @table.remove_column(-3)
      end
    end

    test("too large index") do
      assert_raise(IndexError) do
        @table.remove_column(2)
      end
    end
  end

  sub_test_case("#select_columns") do
    def setup
      raw_table = {
        :a => Arrow::UInt8Array.new([1]),
        :b => Arrow::UInt8Array.new([1]),
        :c => Arrow::UInt8Array.new([1]),
        :d => Arrow::UInt8Array.new([1]),
        :e => Arrow::UInt8Array.new([1]),
      }
      @table = Arrow::Table.new(raw_table)
    end

    test("names") do
      assert_equal(<<-TABLE, @table.select_columns(:c, :a).to_s)
	c	a
0	1	1
      TABLE
    end

    test("range") do
      assert_equal(<<-TABLE, @table.select_columns(2...4).to_s)
	c	d
0	1	1
      TABLE
    end

    test("indexes") do
      assert_equal(<<-TABLE, @table.select_columns(0, -1, 2).to_s)
	a	e	c
0	1	1	1
      TABLE
    end

    test("mixed") do
      assert_equal(<<-TABLE, @table.select_columns(:a, -1, 2..3).to_s)
	a	e	c	d
0	1	1	1	1
      TABLE
    end

    test("block") do
      selected_table = @table.select_columns.with_index do |column, i|
        column.name == "a" or i.odd?
      end
      assert_equal(<<-TABLE, selected_table.to_s)
	a	b	d
0	1	1	1
      TABLE
    end

    test("names, indexes and block") do
      selected_table = @table.select_columns(:a, -1) do |column|
        column.name == "a"
      end
      assert_equal(<<-TABLE, selected_table.to_s)
	a
0	1
      TABLE
    end
  end

  sub_test_case("#save and .load") do
    sub_test_case(":format") do
      test("default") do
        file = Tempfile.new(["red-arrow", ".arrow"])
        @table.save(file.path)
        assert_equal(@table, Arrow::Table.load(file.path))
      end

      test(":batch") do
        file = Tempfile.new(["red-arrow", ".arrow"])
        @table.save(file.path, :format => :batch)
        assert_equal(@table, Arrow::Table.load(file.path, :format => :batch))
      end

      test(":stream") do
        file = Tempfile.new(["red-arrow", ".arrow"])
        @table.save(file.path, :format => :stream)
        assert_equal(@table, Arrow::Table.load(file.path, :format => :stream))
      end

      test(":csv") do
        file = Tempfile.new(["red-arrow", ".csv"])
        @table.save(file.path, :format => :csv)
        assert_equal(@table, Arrow::Table.load(file.path, :format => :csv))
      end

      sub_test_case("load: auto detect") do
        test(":batch") do
          file = Tempfile.new(["red-arrow", ".arrow"])
          @table.save(file.path, :format => :batch)
          assert_equal(@table, Arrow::Table.load(file.path))
        end

        test(":stream") do
          file = Tempfile.new(["red-arrow", ".arrow"])
          @table.save(file.path, :format => :stream)
          assert_equal(@table, Arrow::Table.load(file.path))
        end

        test(":csv") do
          path = fixture_path("with-header.csv")
          assert_equal(<<-TABLE, Arrow::Table.load(path).to_s)
	name	score
0	alice	   10
1	bob 	   29
2	chris	   -1
          TABLE
        end
      end
    end
  end

  test("#pack") do
    packed_table = @table.pack
    column_n_chunks = packed_table.columns.collect {|c| c.data.n_chunks}
    assert_equal([[1, 1], <<-TABLE], [column_n_chunks, packed_table.to_s])
	count	visible
0	    1	true   
1	    2	false  
2	    4	       
3	    8	true   
4	   16	true   
5	   32	false  
6	   64	       
7	  128	       
    TABLE
  end
end
