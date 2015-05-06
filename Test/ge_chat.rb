require 'test/unit'

class TC_Chat < Test::Unit::TestCase

  def setup
    Entities.delete_all_data
    @admin = Persons.create(login_name: 'admin', permissions: %w(admin))
    @center1 = Persons.create(login_name: 'center1', permissions: %w(center),
                              password: '123')
    @clogin1 = {center: {login: 'center1', pass: '123'}}
    @center2 = Persons.create(login_name: 'center2', permissions: %w(center),
                              password: '123')
    @clogin2 = {center: {login: 'center2', pass: '123'}}
    @secretary = Persons.create(login_name: 'secretary', permissions: %w(secretary))
    @accountant = Persons.create(login_name: 'accountant', permissions: %w(accountant))
    @student_1 = Persons.create(login_name: 'student1', permissions: %w(student))
    @student_2 = Persons.create(login_name: 'student2', permissions: %w(student))

    ConfigBase.add_function(:course_server)
    ConfigBase.server_url = 'localhost:3302/icc'
  end

  def teardown
  end

  def with_server
    ConfigBase.block_size = 4096

    @port = 3302
    @url = "http://localhost:#{@port}/icc"
    @main = Thread.new {
      QooxView::startWeb(@port)
    }
    dputs(1) { "Starting at port #{@port}" }
    sleep 1

    yield @port, @url, @main

    @main.kill.join
  end

  def test_push
    ChatMsgs.icc_msg_push(center: {login: 'center1', pass: ''})
    assert_equal '', ChatMsgs.show_list
    @center1.permissions = []
    ChatMsgs.icc_msg_push(@clogin1.merge(person: 'foo', msg: 'hi there'))
    assert_equal '', ChatMsgs.show_list

    @center1.permissions = %w(center)
    ChatMsgs.icc_msg_push(@clogin1.merge(person: 'foo', msg: 'hi there'))
    assert ChatMsgs.show_list =~ / - foo: hi there$/
  end

  def chat_format(r)
    r.select { |k| k == :msg || k == :center || k == :login }
  end

  def test_pull
    assert ChatMsgs.icc_msg_pull(center: {login: 'center1', pass: ''}) =~ /^Error:/
    @center1.permissions = []
    assert ChatMsgs.icc_msg_pull(@clogin1) =~ /^Error:/
    @center1.permissions = %w(center)
    assert !(ChatMsgs.icc_msg_pull(@clogin1) =~ /^Error:/)

    assert_equal [], ChatMsgs.icc_msg_pull(@clogin2)
    ChatMsgs.icc_msg_push(@clogin1.merge({person: 'foo', msg: 'hello1'}))
    assert_equal({msg: 'hello1', center: 'center1', login: 'foo'},
                 chat_format(ChatMsgs.icc_msg_pull(@clogin2).first))
  end

  def test_pull_multi
    assert_equal [], ChatMsgs.icc_msg_push(@clogin1.merge({person: 'foo', msg: 'hello1'}))
    ret = ChatMsgs.icc_msg_push(@clogin2.merge({person: 'foo', msg: 'hello2'}))
    assert_equal({msg: 'hello1', center: 'center1', login: 'foo'},
                 chat_format(ret.first))
    assert_equal({msg: 'hello2', center: 'center2', login: 'foo'},
                 chat_format(ChatMsgs.icc_msg_pull(@clogin1).first))
  end

  def test_time_storage
    ChatMsgs.icc_msg_push(@clogin1.merge({person: 'foo', msg: 'hello1'}))
    Entities.reload
    assert_equal({msg: 'hello1', center: 'center1', login: 'foo'},
                 chat_format(ChatMsgs.icc_msg_pull(@clogin2).first))
    assert_equal [], ChatMsgs.icc_msg_pull(@clogin2)
  end

  def center_hash
    return {} unless center = Persons.center
    {center: {login: center.login_name, pass: center.password_plain}}
  end

  def test_thread
    with_server do
      ChatMsgs.pull_server_start(0.5)
      sleep 1
      assert_equal 0, ChatMsgs.search_all.length
      ChatMsgs.new_msg_send('foo', 'hello1')

      sleep 1
      assert_equal 2, ChatMsgs.search_all.length

      ChatMsgs.pull_server_kill
    end
  end
end