require "#{File.dirname(__FILE__)}/../test_helper.rb"

class InvalidatedModel < Divan::Models::ProofOfConcept
  before_validate :indiferent_callback
  after_validate  lambda{ |obj| obj != nil }
  after_validate  :invalidate

  def indiferent_callback
    true
  end
  
  def invalidate
    false
  end
end

class ViewedModel < Divan::Models::ProofOfConcept
  view_by :value
  view_by :mod
end

class ProofOfConcept < Divan::Models::ProofOfConcept
  
end

class TestDivan < Test::Unit::TestCase
  def test_dynamic_model
    m = Divan::Model(:teste)
    assert m.class, Divan::Models::Teste
    assert m.database.name,     'test'
    assert m.database.host,     '127.0.0.1'
    assert m.database.port,     12345
    assert m.database.user,     'admin'
    assert m.database.password, 'top1secret2pass'
  end

  def test_get_database_stats
    database = Divan[:proof_of_concept]
    assert_equal database.stats[:db_name], 'proof_of_concept'
  end

  def test_create_and_delete_database
    database = Divan::Database.new :created_test_database, 'host' => 'http://127.0.0.1', 'database' => 'test_database'
    delete_lambda = lambda{
      assert database.delete['ok']
      assert !database.exists?
    }
    create_lambda = lambda{
      assert database.create['ok']
      assert_equal database.stats[:db_name], 'test_database'
    }
    delete_lambda.call if database.exists?
    create_lambda.call
    delete_lambda.call
  end

  def test_database_not_found
    database = Divan::Database.new :missing_database, 'host' => 'http://localhost', 'database' => 'mising_database'
    assert_raise(Divan::DatabaseNotFound){ database.stats }
    assert_raise(Divan::DatabaseNotFound){ database.delete }
  end

  def test_database_already_created
    database = Divan::Database.new :already_created, 'host' => 'http://localhost', 'database' => 'already_created'
    assert database.create['ok']
    assert_raise(Divan::DatabaseAlreadyCreated){ database.create }
    assert database.delete['ok'] # Only to ensure that database is deleted after this test
  end

  def test_saving_and_retrieving_simple_document_should_work
    object = Divan::Models::ProofOfConcept.new :simple_param  => 'Working well!',
                                               :hashed_params => { :is_a => 'Hash', :hash_size => 2 }
    assert object.save
    retrieved_object = Divan::Models::ProofOfConcept.find object.id
    assert retrieved_object
    assert retrieved_object.rev
    assert_equal object.id, retrieved_object.id
    assert_equal object.attributes, retrieved_object.attributes
    assert retrieved_object.delete['ok']
    assert_not_equal object.rev, retrieved_object.rev
  end

  def test_retrieving_non_existent_document_should_return_nil
    obj = Divan::Models::ProofOfConcept.find '0'*32 # Probably this uuid don't exists in database
    assert_nil obj
  end  

  def test_updating_document
    object = Divan::Models::ProofOfConcept.new
    object[:hashed_params] = {:is_a => 'Hash', :hash_size => 2}
    object[:simple_param]  = 'Working well!'
    assert object.save
    retrieved_object = Divan::Models::ProofOfConcept.find object.id
    assert retrieved_object
    retrieved_object[:updated_attrib] = 'New attribute!'
    assert retrieved_object.save['ok']
    object[:lost_race] = 'I\'ll fail!'
    assert_raise(Divan::DocumentConflict){ object.save }
  end

  def test_retrieving_deleted_object
    object = Divan::Models::ProofOfConcept.new
    object[:hashed_params] = {:is_a => 'Hash', :hash_size => 2}
    object[:simple_param]  = 'Working well!'
    assert object.save
    assert object.delete
    retrieved_object = Divan::Models::ProofOfConcept.find object.id
    assert_nil retrieved_object
  end

  def test_deleting_document_twice
    object = Divan::Models::ProofOfConcept.new
    object[:hashed_params] = {:is_a => 'Hash', :hash_size => 2}
    object[:simple_param]  = 'Working well!'
    assert object.save
    assert object.delete
    assert_nil object.delete
  end

  def test_save_deleted_document
    object = Divan::Models::ProofOfConcept.new
    object[:hashed_params] = {:is_a => 'Hash', :hash_size => 2}
    object[:simple_param]  = 'Working well!'
    assert object.save
    assert object.delete
    assert object.save
    assert object.delete
  end

  def test_delete_all_from_database
    assert Divan::Models::ProofOfConcept.delete_all
    10.times do |n|
      assert Divan::Models::ProofOfConcept.new( :value => n ).save
    end
    assert Divan[:proof_of_concept].create_views
    assert_equal Divan::Models::ProofOfConcept.delete_all(:limit => 6), 6
    assert_equal Divan::Models::ProofOfConcept.all.first.class, Divan::Models::ProofOfConcept
    assert_equal Divan::Models::ProofOfConcept.delete_all, 4
    assert Divan::Models::ProofOfConcept.find('_design/proof_of_concept')
    assert_equal Divan::Models::ProofOfConcept.all.count, 0
  end

  def test_bulk_create
    assert Divan::Models::ProofOfConcept.delete_all
    params = 10.times.map do |n|
      {:number => n, :double => 2*n}
    end
    assert Divan::Models::ProofOfConcept.create params
    assert_equal Divan::Models::ProofOfConcept.delete_all, 10
  end

  def test_perform_view_by_query
    assert ViewedModel.delete_all
    assert Divan[:proof_of_concept].create_views
    params = 10.times.map do |n|
      {:mod => (n%2), :value => "#{n} mod 2"}
    end
    assert ViewedModel.create params
    obj = ViewedModel.by_value '5 mod 2'
    assert obj
    assert_equal obj.mod, 1
    assert_equal ViewedModel.all_by_mod(0).count, 5
    assert_equal ViewedModel.delete_all, 10
  end

  def test_before_validate_callback_avoids_save
    object = InvalidatedModel.new
    assert !object.save
    assert_nil object.rev
  end

  def test_dynamic_access_to_attributes
    object = Divan::Models::ProofOfConcept.new :dynamic_attribute => 'Working'
    assert object.dynamic_attribute, 'Working'
    assert_equal( (object.dynamic_setter = "Well"), 'Well')
    assert_equal object.dynamic_setter, 'Well'
  end
end