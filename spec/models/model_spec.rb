require 'spec_helper'

class TestItem < Volt::Model
end

class Item < Volt::Model
end

class Items < Volt::ArrayModel
end

class TestAssignsMethod < Volt::Model
  def name=(val)
    self._name = val
  end
end

describe Volt::Model do
  it 'delegates unary operator to its attributes' do
    model = Volt::Model.new
    expect(!model).to eq(!model.attributes)
    model = Volt::Model.new(has: 'attrs')
    expect(!model).to eq(!model.attributes)
  end

  it 'should allow _ methods to be used to store values without predefining them' do
    a = Volt::Model.new
    a._stash = 'yes'

    expect(a._stash).to eq('yes')
  end

  it 'should update other values off the same model' do
    a = Volt::Model.new

    values = []
    -> { values << a._name }.watch!

    expect(values).to eq([nil])
    Volt::Computation.flush!

    a._name = 'Bob'

    Volt::Computation.flush!
    expect(values).to eq([nil, 'Bob'])
  end

  it 'should say unregistered attributes are nil' do
    a = Volt::Model.new
    b = a._missing.nil?
    expect(b).to eq(true)
  end

  it 'should negate nil and false correctly' do
    a = Volt::Model.new
    expect((!a._missing)).to eq(true)

    a._mis1 = nil
    a._false1 = false

    expect(!a._mis1).to eq(true)
    expect(!a._false1).to eq(true)
  end

  it "should return an empty model for an underscore value that doesn't exist" do
    a = Volt::Model.new
    expect(a._something!.attributes.without(:id)).to eq({})
  end

  it 'should trigger changed once when a new value is assigned.' do
    a = Volt::Model.new

    count = 0
    -> { a._blue; count += 1 }.watch!
    expect(count).to eq(1)

    a._blue = 'one'
    Volt::Computation.flush!
    expect(count).to eq(2)

    a._blue = 'two'
    Volt::Computation.flush!
    expect(count).to eq(3)
  end

  it 'should not trigger changed on other attributes' do
    a = Volt::Model.new

    blue_count = 0
    green_count = 0

    -> { a._blue; blue_count += 1 }.watch!
    -> { a._green; green_count += 1 }.watch!
    expect(blue_count).to eq(1)
    expect(green_count).to eq(1)

    a._green = 'one'
    Volt::Computation.flush!
    expect(blue_count).to eq(1)
    expect(green_count).to eq(2)

    a._blue = 'two'
    Volt::Computation.flush!
    expect(blue_count).to eq(2)
    expect(green_count).to eq(2)
  end

  it 'should call change through arguments' do
    a = Volt::Model.new
    a._one = 1
    a._two = 2
    a._three = 3

    c = nil
    count = 0
    -> { c = a._one + a._two; count += 1 }.watch!

    expect(count).to eq(1)

    a._two = 5
    Volt::Computation.flush!
    expect(count).to eq(2)

    a._one = 6
    Volt::Computation.flush!
    expect(count).to eq(3)

    a._three = 7
    Volt::Computation.flush!
    expect(count).to eq(3)
  end

  it 'should update through a normal array' do
    model = Volt::Model.new
    array = []
    array << model

    values = []

    -> { values << array[0]._prop }.watch!

    expect(values).to eq([nil])

    model._prop = 'one'
    Volt::Computation.flush!

    expect(values).to eq([nil, 'one'])
  end

  it 'should trigger changed for any indicies after a deleted index' do
    model = Volt::Model.new

    model._items! << { _name: 'One' }
    model._items << { _name: 'Two' }
    model._items << { _name: 'Three' }

    count = 0
    -> { model._items[2]; count += 1 }.watch!
    expect(count).to eq(1)

    model._items.delete_at(1)
    Volt::Computation.flush!
    expect(count).to eq(2)
  end

  it 'should change the size and length when an item gets added' do
    model = Volt::Model.new

    model._items! << { _name: 'One' }
    size = model._items.size
    length = model._items.length

    count_size = 0
    count_length = 0
    -> { model._items.size; count_size += 1 }.watch!
    -> { model._items.length; count_length += 1 }.watch!
    expect(count_size).to eq(1)
    expect(count_length).to eq(1)

    model._items << { _name: 'Two' }
    Volt::Computation.flush!

    expect(count_size).to eq(2)
    expect(count_length).to eq(2)
  end

  it 'should add doubly nested arrays' do
    model = Volt::Model.new

    model._items! << { name: 'Cool', lists: [] }
    model._items[0]._lists! << { name: 'worked' }
    expect(model._items[0]._lists[0]._name).to eq('worked')
  end

  it 'should make pushed subarrays into ArrayModels' do
    model = Volt::Model.new

    model._items! << { _name: 'Test', _lists: [] }
    expect(model._items[0]._lists.class).to eq(Volt::ArrayModel)
  end

  it 'should make assigned subarrays into ArrayModels' do
    model = Volt::Model.new

    model._item!._name = 'Test'
    model._item._lists = []
    expect(model._item._lists.class).to eq(Volt::ArrayModel)
  end

  it 'should call changed when an expanded reference changes' do
    a = Volt::Model.new

    count = 0
    -> { a._blue; count += 1 }.watch!

    expect(count).to eq(1)

    a._blue!
    Volt::Computation.flush!

    expect(count).to eq(2)
  end

  it 'should call size changed when adding to an ArrayModel' do
    a = Volt::Model.new

    count = 0
    -> { count = a._todos.size }.watch!

    expect(count).to eq(0)

    a._todos << { label: 'Be active' }
    Volt::Computation.flush!

    expect(count).to eq(1)
  end

  unless RUBY_PLATFORM == 'opal'
    it 'should track changes through an expansion' do
      a = Volt::Model.new

      last_count = 0
      -> { last_count = a._todos.count(&:_checked).sync }.watch!

      expect(last_count).to eq(0)

      a._todos! << { checked: true }
      Volt::Computation.flush!

      expect(last_count).to eq(1)
    end
  end

  it 'should call changed when a the reference to a submodel is assigned to another value' do
    a = Volt::Model.new

    count = 0
    a._blue!
    -> { a._blue && a._blue.respond_to?(:_green) && a._blue._green; count += 1 }.watch!
    expect(count).to eq(1)

    a._blue._green = 5
    Volt::Computation.flush!

    expect(count).to eq(2)

    a._blue = 22
    Volt::Computation.flush!
    expect(count).to eq(3)

    a._blue = { green: 50 }
    expect(a._blue!._green).to eq(50)
    Volt::Computation.flush!
    expect(count).to eq(4)
  end

  it 'should trigger changed when a value is deleted' do
    a = Volt::Model.new

    count = 0
    -> { a._blue; count += 1 }.watch!
    expect(count).to eq(1)

    a._blue = 1
    Volt::Computation.flush!
    expect(count).to eq(2)

    a.delete(:blue)
    Volt::Computation.flush!
    expect(count).to eq(3)
  end

  it 'should let you append nested hashes' do
    a = Volt::Model.new

    a._items! << { name: { text: 'Name' } }

    expect(a._items[0]._name!._text).to eq('Name')
  end

  it 'should not call added too many times' do
    a = Volt::Model.new
    a._lists! << 1

    count = 0
    a._lists.on('added') { count += 1 }
    expect(count).to eq(0)

    a._lists << 2
    expect(count).to eq(1)
  end

  it 'should propigate to different branches' do
    a = Volt::Model.new

    # Expand first
    a._new_item!
    count = 0
    lambda do
      count += 1
      a._new_item._name
    end.watch!
    expect(count).to eq(1)

    a._new_item._name = 'Testing'
    Volt::Computation.flush!
    expect(count).to eq(2)
  end

  describe 'paths' do
    it 'should store the path' do
      a = Volt::Model.new
      expect(a._test!.path).to eq([:test])
      a._test = { _name: 'Yes' }
      expect(a._test.path).to eq([:test])

      a._items! << { _name: 'Yes' }
      expect(a._items.path).to eq([:items])
      expect(a._items[0].path).to eq([:items, :[]])
    end

    it 'should store the paths when assigned' do
      a = Volt::Model.new

      a._items = [{ _name: 'Cool' }]

      expect(a._items.path).to eq([:items])
      expect(a._items[0].path).to eq([:items, :[]])
    end

    it 'should handle nested paths' do
      a = Volt::Model.new

      a._items! << { name: 'Cool', lists: [{ name: 'One' }, { name: 'Two' }] }

      expect(a._items[0]._lists.path).to eq([:items, :[], :lists])
      expect(a._items[0]._lists[1].path).to eq([:items, :[], :lists, :[]])
    end

    it 'should trigger added when added' do
      a = Volt::Model.new
      count = 0
      b = a._items!

      b.on('added') { count += 1 }
      expect(count).to eq(0)

      b << { _name: 'one' }
      b << { _name: 'two' }

      expect(count).to eq(2)
    end
  end

  it 'should trigger on false assign' do
    a = Volt::Model.new
    count = 0

    -> { count += 1; a._complete }.watch!

    expect(count).to eq(1)

    a._complete = true
    Volt::Computation.flush!
    expect(count).to eq(2)

    a._complete = false
    Volt::Computation.flush!
    expect(count).to eq(3)
  end

  it 'should delete from an ArrayModel' do
    array = Volt::ArrayModel.new([])

    array << { name: 'One' }
    array << { name: 'Two' }
    array << { name: 'Three' }

    expect(array.size).to eq(3)

    expect(array.index(array[0])).to eq(0)

    array.delete(array[0])
    expect(array.size).to eq(2)
    expect(array[0]._name).to eq('Two')
  end

  it 'should compare true' do
    a = Volt::Model.new(_name: 'Cool')
    expect(a == a).to eq(true)
  end

  it 'should do index' do
    a = [{ name: 'One' }, { name: 'Two' }, { name: 'Three' }]
    expect(a.index(a[1])).to eq(1)
  end

  it 'should convert to a hash, and unwrap all of the way down' do
    a = Volt::Model.new
    a._items! << { name: 'Test1', other: { time: 'Now' } }
    a._items << { name: 'Test2', other: { time: 'Later' } }

    item1 = a._items[0].to_h
    expect(item1[:name]).to eq('Test1')
    expect(item1[:other][:time]).to eq('Now')

    all_items = a._items.to_a

    a = [
      { name: 'Test1', other: { time: 'Now' } },
      { name: 'Test2', other: { time: 'Later' } }
    ]

    # Remove id's nested
    items = all_items.map do |hash|
      hash.without(:id).map do |k,v|
        v = v.without(:id) if v.is_a?(Hash)
        [k,v]
      end.to_h
    end
    expect(items).to eq(a)
  end

  describe "first or create" do
    it 'should create an item if one does not exist in the collection' do
      page = Volt::Model.new

      result = page._items.first_or_create
      expect(result.class).to eq(Promise)

      result.then do |item|
        expect(page._items.size).to eq(1)
        page._items[0].then do |item2|
          expect(item).to eq(item2)
        end
      end
    end
  end

  describe 'model paths' do
    before do
      @model = Volt::Model.new
    end

    it 'should set the model path' do
      @model._object!._name = 'Test'
      expect(@model._object.path).to eq([:object])
    end

    it 'should set the model path for a sub array' do
      @model._items! << { name: 'Bob' }
      expect(@model._items.path).to eq([:items])
      expect(@model._items[0].path).to eq([:items, :[]])
    end

    it 'should set the model path for sub sub arrays' do
      @model._lists! << { name: 'List 1', items: [] }
      expect(@model._lists[0]._items!.path).to eq([:lists, :[], :items])
    end

    it 'should update the path when added from a model instance to a collection' do
      test_item = TestItem.new

      @model._items! << test_item
      expect(@model._items[0].path).to eq([:items, :[]])
    end
  end

  describe 'reserved attributes' do
    let(:model) { Volt::Model.new }

    it 'should prevent reserved attributes from being read with underscores' do
      [:attributes, :parent, :path, :options, :persistor].each do |attr_name|
        expect do
          model.send(:"_#{attr_name}")
        end.to raise_error(Volt::InvalidFieldName, "`#{attr_name}` is reserved and can not be used as a field")
      end
    end

    it 'should prevent reserved attributes from being assigned directly' do
      [:attributes, :parent, :path, :options, :persistor].each do |attr_name|
        expect do
          model.send(:"_#{attr_name}=", 'assign val')
        end.to raise_error(Volt::InvalidFieldName, "`#{attr_name}` is reserved and can not be used as a field")
      end
    end
  end

  describe 'persistors' do
    it 'should setup a new instance of the persistor with self' do
      persistor = double('volt/persistor')
      expect(persistor).to receive(:new)
      @model = Volt::Model.new(nil, persistor: persistor)
    end
  end

  if RUBY_PLATFORM != 'opal'
    describe 'class loading' do
      it 'should load classes for models' do
        @model = Volt::Model.new

        # Should return a buffer of the right type
        expect(@model._items!.buffer.class).to eq(Item)

        # Should insert as the right type
        @model._items << { _name: 'Item 1' }
        expect(@model._items[0].class).to eq(Item)
      end
    end
  end

  it 'should have assignments optionally go through a method' do
    model = TestAssignsMethod.new

    model._name = 'Jimmy'

    expect(model._name).to eq('Jimmy')
  end

  describe 'model state' do
    it 'should be new when created, then false after a change' do
      a = Volt::Model.new
      expect(a.new?).to eq(true)

      a._name = 'Ryan'
      expect(a.new?).to eq(false)
    end

    it 'should allow multiple assignments with attributes, changing new? to false after' do
      a = Volt::Model.new
      expect(a.new?).to eq(true)

      a.attributes = { first: 'Jimmy', last: 'Dean' }
      expect(a.new?).to eq(false)
    end
  end

  if RUBY_PLATFORM != 'opal'
    it 'should update other queries on the server when a new model is created' do
      query1 = store._todos!
      query2 = store._todos.limit(1)

      count = 0

      # count the number of todos
      query2.all.each { |v| count += 1 }

      expect(count).to eq(0)

      query1 << { label: 'One' }

      count = 0
      query2.all.each { |v| count += 1 }

      expect(count).to eq(1)
    end

    it 'should query twice and return twice' do
      store._items << { name: 'One' }
      store._items << { name: 'Two' }

      a = store._items
      b = store._items

      expect(a.size.sync).to eq(2)
      expect(b.size.sync).to eq(2)

      expect(a.all.to_a.sync).to eq(b.all.to_a.sync)
    end
  end

  describe 'destroy' do
    it 'fails if attempting to destroy while parentless' do
      model = Volt::Model.new(test: "yeah")
      expect { model.destroy }.to raise_error(RuntimeError,
        'Model does not have a parent and cannot be deleted.')
    end
  end

  describe 'serialization' do
    it 'supports JSON via to_json' do
      model = Volt::Model.new({})
      expect(model.to_json).to eq(model.to_h.to_json)
      expect(model.to_json).to eq(model.to_h.to_json)
      array_model = Volt::ArrayModel.new([model])
      expect(array_model.to_json).to eq(array_model.to_a.to_json)
    end
  end

  it 'creates sub-arrays with correct classes' do
    model = Volt::Model.new
    model._items << {}
    expect(model._items).to be_instance_of Items
  end
end
