class Quizs < Entities
  def setup_data
    value_str :email
    value_str :full_name
    value_str :reply
    value_int :score
  end

  def create( a )
    dputs 4, "Creating Quiz with #{a.inspect}"
    q = super( a )
    q.score = q.evaluate
    q
  end
end

class Quiz < Entity
  def evaluate
    correct = %w( 1992 2007 faux route fai faux faux courriel www faux recherche ouvert
      90 55000 ICANN IANA IAB NTIC isoc-chad.org )
    s = 0
    reply.split(",")[0..-2].each{|r|
      r.to_s == correct.shift.to_s and s += 1
    }
    s
  end

end
