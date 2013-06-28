Shoes.app :height => 375, :width => 500, :title => "Poker Bot" do
  stack do
    para "CARD FORMAT: two characters [2..9TJQKA][CDHS] written together.\nExamples: 2C 9H TS QD KC AH\nSuggested number of simulations: 1000+"
    flow do
      para "Number of game simulations:\t"
      @num_sims = edit_line
    end
    flow do
      para "Your cards:\t\t\t\t\t"
      @cards = edit_line
    end
    flow do
      para "Public cards:\t\t\t\t\t"
      @public = edit_line
    end
    flow do
      para "Number of opponents:\t\t\t"
      @num_opp = edit_line
    end
    flow do
      para "Amount to call:\t\t\t\t"
      @call = edit_line
    end
    flow do
      para "Money in pot currently:\t\t\t"
      @pot = edit_line
    end
    flow do
      button "WHAT SHOULD I DO?" do
        @action.replace "..."
        ai = AI.new @num_sims.text.to_i
        ai.num_opponents = @num_opp.text.to_i
        ai.set_pot_odds(@call.text.to_i, @pot.text.to_i)
        ai.private = Card.make *(@cards.text.split(' '))
        ai.public = Card.make *(@public.text.split(' '))
        @action.replace "\t#{ai.action}"
      end  
      @action = title ""
    end
  end
end