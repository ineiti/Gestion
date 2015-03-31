require 'test/unit'

class TC_View < Test::Unit::TestCase

  def setup
    #Entities.delete_all_data()
    #@admin = Entities.Persons.create(:login_name => 'admin', :password => 'super123',
    #                                 :permissions => ['default'])
    @foo = Entities.Persons.create(:login_name => 'foo', :password => 'bar',
                                     :permissions => %w(default internet admin))
  end

  def teardown

  end

=begin
Going to call View.Welcome, button. Args = [["login", {"username"=>"linus", "password"=>"1234", "version"=>"1.9.5-orig", "reason"=>
                                nil, "links"=>"<h1>Markas-al-Nour</h1>\n<p>Bienvenue sur le réseau du centre Markas-al-Nour. <br>\nSi vous avez un compte, vous
                                pouvez vous connecter.<br>\nDans le cas contraire vous pouvez chercher <br>\nun login et mot de passe au secrétariat.</p>\n<!--p>
                                Nouvelle version 1.3.0-rc1 est installée! Partagez les erreurs avec nous...</p-->\n<p>Voici quelques liens que vous pouvez
                                consulter gratuitement:\n<ul>\n<li>Telechargements pour divers systemes: <a href=\"http://files.ndjair.net\">files.ndjair.net</a>
                                </li>\n<li>Site du cours:  <a href=\"http://cours.markas-al-nour.org\">cours.markas-al-nour.org</a></li>\n\n  \n"}]]
:2:Person`check_pass'********* is 1234 equal to 1234
:1:DPuts`log_msg'xxxxxxxxxxxxx Info from Welcome: Authenticated person linus from ::1
:2:RPCQooxdoo`request'******** Final answer is [{:cmd=>:session_id, :data=>"0.3287243066713256"}, {:cmd=>:list, :data=>{:views=>[["SelfTabs", "Mon compte"],
                                ["PersonTabs", "Personnes"], ["CourseTabs", "Cours"], ["AdminTabs", "Administration"], ["InventoryTabs", "Inventaire"],
                                ["TemplateTabs", "Modèles"], ["NetworkTabs", "Réseau"], ["InternetTabs", "InternetTabs"], ["CashboxTabs", "Entrées"],
                                ["ComptaTabs", "Comptabilité"], ["LibraryTabs", "Bibliothèque"], ["ReportTabs", "Rapports"]]}}]
:2:RPCQooxdoo`request'******** Going to call View.SelfTabs, show. Args = [[]]
:2:RPCQooxdoo`request'******** Final answer is [{:cmd=>"show", :data=>{:layout=>["groupw", [["hboxg", [["vbox", []], ["tabs", [["SelfTabs", []]]]]]]],
                                :data_class=>"NilClass", :view_class=>"SelfTabs"}}]
:2:RPCQooxdoo`request'******** Going to call View.SelfTabs, list_tabs. Args = [[]]
:2:RPCQooxdoo`request'******** Final answer is [{:cmd=>"list", :data=>{:views=>[["SelfInternet", "Internet"], ["SelfShow", "Adresse"], ["SelfChat",
                                "Discuter"]]}}]
:2:RPCQooxdoo`request'******** Going to call View.SelfInternet, show. Args = [[]]
=end

  def get_reply(service, method, session, arguments = [])
    #dp RPCQooxdooService::services
    s = RPCQooxdooService::services["View.#{service}"]
    m = "rpc_#{method}"
    parsed = s.parse_request(m, session, arguments)
    s.parse_reply(m, session, parsed)
  end

  def test_speed_login
    Struct.new('Webreq', :header, :peeraddr)
    (1..200).each { |i|
      Timing.measure("Measure #{i}") {
        session = Sessions.create
        session.web_req = Struct::Webreq.new({host: 'nil'}, [0, 0, 0, '192.168.1.1'])
        ret = get_reply(:Welcome, :button, session,
                        ['login', {'username' => 'foo', 'password' => 'bar'}])
        session = Sessions.match_by_sid(ret[0]._data)
        get_reply(:SelfTabs, :show, session, [])
        get_reply(:SelfTabs, :list_tabs, session, [])
        get_reply(:SelfInternet, :show, session, [])
        get_reply(:PersonTabs, :show, session)
        get_reply(:PersonTabs, :list_tabs, session)
        get_reply(:PersonModify, :show, session)
        if i % 10 == 0
          Entities.save_all
        end
      }
    }
  end
end