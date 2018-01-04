# Copyright 2017 Kouhei Sutou <kou@clear-code.com>
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

class Date32ArrayTest < Test::Unit::TestCase
  test("#[]") do
    n_days_since_epoch = 17406 # 2017-08-28
    array = Arrow::Date32Array.new([n_days_since_epoch])
    assert_equal(Date.new(2017, 8, 28), array[0])
  end
end
