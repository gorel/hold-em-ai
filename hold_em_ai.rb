# Author: Logan Gore
# Date last updated: 6/19/2013
# Purpose: A poker-playing AI designed to make decisions for Texas Hold 'Em games (although can be easily repurposed for any poker game)

class Card
  # Allow the card's suit and value to be read
  attr_reader :value, :suit
  
  # Suits: 0..3 (0 == Clubs, 1 == Diamonds, 2 == Hearts, 3 == Spades)
  # Values: 1..13 (0..8 == 2..10, 9 == Jack, 10 == Queen, 11 == King, 12 == Ace)
  # seed should be in range 0..51
  # if seed is a string, it should be two characters: [2..9TJQKA] + [CDHS]
  def initialize(seed)
    if seed.class == String
      @value = getval(seed)
      @suit = getsuit(seed)
    else
      @value = seed % 13
      @suit = seed / 13
    end
  end
  
  # Return the value a card should have when seeded with a String
  def getval(seed)
    case seed[0]
    when "2".."9"
      seed[0].to_i - 2
    when "T"
      8
    when "J"
      9
    when "Q"
      10
    when "K"
      11
    when "A"
      12
    end
  end
  
  # Return the suit a card should have when seeded with a String
  def getsuit(seed)
    case seed[1]
    when "C"
      0
    when "D"
      1
    when "H"
      2
    when "S"
      3
    end
  end
  
  # Defines card equality -- two cards are equal if their values and suits are equivalent
  def == (other)
    @value == other.value and @suit == other.suit
  end
  
  # Output of cards should be in the form "<Value> of <Suit>"
  def to_s
    case @value
    when 0..8
      val = @value + 2
    when 9
      val = "Jack"
    when 10
      val = "Queen"
    when 11
      val = "King"
    when 12
      val = "Ace"
    end
    case @suit
    when 0
      suit = "Clubs"
    when 1
      suit = "Diamonds"
    when 2
      suit = "Hearts"
    when 3
      suit = "Spades"
    end
    "#{val} of #{suit}"      
  end
  
  # Class method to return an array of cards created with an unknown number of seed values (which may be integers or Strings)
  def self.make(*seeds)
    # Initialize the result array as an empty array
    result = []
    
    # For each seed given, create a new card and add it to the result array
    seeds.each {|seed| result << Card.new(seed)}
    
    # Return the result array
    return result
  end
end

class AI
  # Class constants to define the hand ranking hierarchy
  STRAIGHT_FLUSH = 8
  FOUR_OF_A_KIND = 7
  FULL_HOUSE = 6
  FLUSH = 5
  STRAIGHT = 4
  THREE_OF_A_KIND = 3
  TWO_PAIR = 2
  PAIR = 1
  HIGH_CARD = 0
  
  # Allow the private cards, public cards, number of opponents, call value, blind value, and amount of cash the user has to be read
  attr_accessor :private, :public, :num_opponents, :call, :cash, :blind
  
  # Initialize a new AI that will make decisions based on the given number of iterations (how many games the AI should simulate)
  # And with the given amount of cash (or a default of 1000)
  def initialize(iterations, cash = 1000)
    # Output the correct usage of the AI for the user
    puts "USAGE EACH ROUND: initialize cards, set pot odds, set num_opponents, call method 'action', [ai.public << new card] as needed, update pot odds and num_opponents, end round"
    @public = @private = []
    @iterations = iterations
    @cash = cash
  end
  
  # Sets the pot odds for the current round by setting the call, blind, and current pot values
  def set_pot_odds(call, blind, current)
    @blind = blind
    @call = call
    
    # If the call is not zero, calculate pot odds by the formula Pot odds = call / (call + current pot value) 
    if call != 0
      @pot_odds = call / (call + current.to_f)
    else
      # Otherwise, set the pot odds to 0.5 (default value when other players' "confidence" is unknown due to no betting)
      @pot_odds = 0.5
    end
  end
  
  # Returns the action the AI thinks the user should perform based on the inputs given by the user
  def action
    # Begin by calculating the rate of return for the user
    calculate_rate_of_return
    
    # If no public cards have been shown yet, increase the rate of return by 0.1
    # This increases the AI "confidence" since there are so many variables in play -- leads to a slightly more aggressive AI -- decrease to increase passivity
    @rate_of_return += 0.2 if @public.size == 0
    
    # Create a random number to help make the AI more humanlike -- and, more importantly, less predictable -- without drastically affecting prime choice of action
    val = rand
    
    # If our cash minus the call amount is less than four times the blind and we have less than a 50% chance of winning, FOLD
    # The AI should play conservative since the user does not have much room for error
    if (@cash - @call) < (@blind * 4) and @hand_strength < 0.5
      action = "FOLD"
    # If the rate of return is below 0.8: FOLD 95% of the time and RAISE 5% of the time (the AI attempts to "bluff")
    # Note: The AI will also RAISE if the call is zero.  It makes no sense to FOLD if there is no cost for staying  
    elsif @rate_of_return < 0.8
      if val < 0.95 and @call > 0
        action = "FOLD"
      else
        action = "RAISE"
      end
    # If the rate of return is between 0.8 and 1.0: FOLD 80% of the time, CALL 5% of the time, and RAISE 15% of the time (the AI attempts to "bluff")
    # Note: The AI will also CALL if the call is zero.  It makes no sense to FOLD if there is no cost for staying
    elsif @rate_of_return < 1
      if val < 0.8 and @call > 0
        action = "FOLD"
      elsif val < 0.85
        action = "CALL"
      else
        action = "RAISE"
      end
    # If the rate of return is between 1.0 and 1.3: CALL 60% of the time and RAISE 40% of the time
    elsif @rate_of_return < 1.3
      if val < 0.6
        action = "CALL"
      else
        action = "RAISE"
      end
    # If the rate of return is above 1.3 (Great odds): CALL 30% of the time and RAISE 70% of the time
    else
      if val < 0.3
        action = "CALL"
      else
        action = "RAISE"
      end
    end
  end
  
  # Set up the AI for a new round by setting the private and public cards to empty arrays and setting the call to zero
  def end_round
    @private = []
    @public = []
    @call = 0
  end
  
  # Finds the user's hand strength by simulating games with the given "knowns" of the game
  # The hand strength variable is a float between 0 and 1 which represents the number of wins over how many games were simulated
  def calculate_hand_strength
    # Initialize the score to zero
    score = 0
    
    # Iterate however many times the AI was set up to simulate
    @iterations.times do |i|
      # Add one to the score if the user wins the simulated game
      score += 1 if simulate_game
    end
    
    # Calculate the hand strength by dividing the number of games won by how many games were simulated
    @hand_strength = score / @iterations.to_f
  end
  
  # Calculates the rate of return by dividing the hand strength by the pot odds
  def calculate_rate_of_return
    @rate_of_return = calculate_hand_strength / @pot_odds
  end

# Private methods for internal use only -- should not be called by the user
private
  
  # Find out if the given card ranks contain a pair of cards.  If so: return the value of the card pair.  If not: return false
  def pair?(ranks)
    # For each rank...
    ranks.each do |val|
      # If there are exactly two of that value in the ranks array, return that value
      return val if ranks.count(val) == 2
    end
    
    # No pair was found.  Return false
    return false
  end
  
  # Find out if the given card ranks contain two pairs of cards.  If so: return the value of the higher and lower card pairs.  If not: return false
  def two_pair?(ranks)
    # Get the higher pair
    higher_pair = pair?(ranks)
    
    # Get the lower pair by reversing the ranks order
    lower_pair = pair?(ranks.reverse)
    
    # If a pair was found and the higher pair does not equal the lower pair, return the two pairs
    # Note, we don't have to check that lower_pair is not false -- if higher_pair is not false, lower_pair will just return the same pair (which warrants the check that they are not equal) 
    if higher_pair and (higher_pair != lower_pair)
      return [higher_pair, lower_pair] 
    else
      # Otherwise, return false
      return false
    end
  end
  
  # Find out if the given card ranks contain three of a kind.  If so: return the value of the three of a kind.  If not: return false
  def three_of_a_kind?(ranks)
    # For each rank...
    ranks.each do |val|
      # If there are exactly three of that value in the ranks array, return that value
      return val if ranks.count(val) == 3
    end
    
    # No three of a kind was found.  Return false
    return false
  end
  
  # Find out if the given ranks contain a straight.  If so: return the maximum value of the straight.  If not: return false
  def straight?(ranks)
    # We need to take consecutive "slices" of the array to see if a run of 5 exists
    ranks.each_cons(5) do |slice|
      # If the size of the unique values of the slice is 5... (easy test to weed out obviously wrong values)
      if slice.uniq.length == 5
        # Return the maximum value in the slice if the difference between the slice's maximum and minimum values is four
        # Note: This works because we know the slice contains five unique values.  If the length is 5 and the difference is 4, we know we have a run of 5
        return slice.max if slice.max - slice.min == 4
        
        # Account for "Ace low" straights.  Return the value 3 (NOTE: returning 3 means that our high card was a 5) if we have the values A, 2, 3, 4, 5
        return 3 if slice - [0, 1, 2, 3, 12] == []
      end
    end
      
    # No straight was found.  Return false
    return false
  end

  # Find out if the given cards contain a flush.  If so: return the cards that made a flush.  If not: return false  
  def flush?(cards)
    # Create a copy of the cards sorted by suit to optimize the flush check
    cards_copy = cards.sort_by {|card| card.suit}
    
    # If we don't even have five cards, we can prematurely return false
    return false if cards.size < 5
    
    # We need to take consecutive "slices" of the array to see if a set of 5 cards all with the same suit exists
    cards_copy.each_cons(5) do |slice|
      # Map the card slice to a new array with a list of the slice's suits
      suits = slice.map {|card| card.suit}
      
      # If only one suit was found, a flush was found -- return the slice containing the flush
      return slice if suits.uniq.length == 1
    end
    
    # No flush was found.  Return false
    return false
  end
  
  # Find out if the given cards contain a full house.  If so: return the 'top' and 'over' sets (The three of a kind and pair sets)
  def full_house?(ranks)
    # Try to find a three of a kind and set it equal to 'top', and try to find a pair and set it equal to 'over'
    # Note: By keeping all code in line this way, we skip the pair check if the three of a kind check returns false first
    if (top = three_of_a_kind?(ranks)) and (over = pair?(ranks))
      # Return the three of a kind set and the pair set
      return [top, over]
    end
    
    # No full house was found.  Return false
    return false    
  end
  
  # Find out if the given cards contain a four of a kind.  If so: return the value of the four of a kind.  If not: return false 
  def four_of_a_kind?(ranks)
    # For each rank...
    ranks.each do |val|
      # If there are exactly four of that value in the ranks array, return that value
      return val if ranks.count(val) == 4
    end
    
    # No four of a kind was found.  Return false
    return false
  end
  
  # Rate a player's hand by checking if the hand contains various "values" of poker hands
  def rate_hand(cards)
    # Sort the given cards by value
    cards = cards.sort_by {|card| card.value}
    
    # Create the ranks array by only storing each card's value.  This will reduce overhead for a number of functions.
    # This is because many poker hands rely only on card values, not suits (flush being the exception)
    ranks = cards.map {|card| card.value}
    
    # If a flush was found, and a straight can be made out of those cards' ranks, return STRAIGHT_FLUSH
    if (flush_set = flush?(cards)) and (val = straight?(flush_set.map {|card| card.value}))
      return [STRAIGHT_FLUSH, val]
      
    # If a four of a kind was found, return FOUR_OF_A_KIND
    elsif val = four_of_a_kind?(ranks)
      return [FOUR_OF_A_KIND, val, ranks]
      
    # If a full house was found, return FULL_HOUSE
    elsif val = full_house?(ranks)
      return [FULL_HOUSE, val[0], val[1]]
      
    # If a flush was found, return FLUSH 
    elsif flush?(cards)
      return [FLUSH, ranks]
      
    # If a straight was found, return STRAIGHT 
    elsif val = straight?(ranks)
      [STRAIGHT, val]
      
    # If a three of a kind was found, return THREE_OF_A_KIND
    elsif val = three_of_a_kind?(ranks)
      [THREE_OF_A_KIND, val, ranks]
      
    # If two pairs were found, return TWO_PAIR
    elsif val = two_pair?(ranks)
      [TWO_PAIR, val, ranks]
    
    # If a pair was found, return PAIR
    elsif val = pair?(ranks)
      [PAIR, val, ranks]
    
    # Otherwise, no poker hand was found.  Return HIGH_CARD
    else
      [HIGH_CARD, ranks]
    end
  end

  # Simulates a poker game and determine if the AI won  
  def simulate_game
    # Create a new deck
    deck = (0...52).map {|val| Card.new(val)}
    
    # Delete all cards in the deck which have already been revealed (the public cards and the AI's private cards)
    deck.delete_if {|card| @private.include? card or @public.include? card}
    
    # Shuffle the deck 25 times
    25.times {deck.shuffle!}
    
    # Duplicate the public cards so we won't alter the known data
    public = @public.dup
    
    # Increase the public cards copy until we have five public cards (we want to simulate the end of a Texas Hold 'Em game)
    (5 - public.size).times {public << deck.shift}
    
    # Create opponents which will be represented by two private cards
    opponents = Array.new(@num_opponents, [])
    
    # Generate the private cards for each opponent
    2.times do |iter|
      opponents.each {|opponent| opponent << deck.shift}
    end
    
    # Score the AI's hand by rating the hand of the AI's private cards and the public cards copy
    my_score = rate_hand(@private + public)[0]
    
    #TODO: Change how this method determines a winner
    # => Currently, the algorithm considers all things equal if two people each 'win' with a pair
    # => the value of the pair is not considered
    # => Since this can equally help or hurt the AI, a fix is not code-breaking, but it decreases accuracy
    
    # Score the other players' hands by rating the hand of their private cards and the public cards copy
    other_scores = opponents.map {|cards| rate_hand(cards + public)[0]}
    
    # Return whether or not the AI won the simulated game
    return my_score >= other_scores.max
  end
end

# Testing code to see how fast the algorithm will run
# => Test: Create an AI to make random decisions with no public cards given
# => The AI will determine whether the user should FOLD, CALL, or RAISE based on two random private cards
# => It will then output it's average time after 100 random trials

# TEST CONSTANTS
NUM_OPPONENTS = 3
POT_ODDS = [50, 50, 150]

# The array to store the times required to reach each decision
times = []

# This will be used to create  a random set of cards
card_range = 0...52

# Create the AI which will simulate 2500 games to reach each decision
test_ai = AI.new 2500
test_ai.num_opponents = NUM_OPPONENTS

# Perform 100 trials
100.times do
  # Create the first random card
  card1 = rand(card_range) 
  begin
    # Create the second random card -- loop to make sure this isn't the same card as the first random card
    card2 = rand(card_range)
  end while card1 == card2
  
  # Create the Card objects and set them as the AI's cards
  my_cards = Card.make(card1, card2)
  
  # Set the pot odds for the AI
  test_ai.set_pot_odds *POT_ODDS
  
  # Start the timer
  start = Time.now
  
  # Set the AI's private cards to the card's generated at the beginning of this loop
  test_ai.private = my_cards
  
  # Output which cards the AI had and what decision it reached about those cards
  puts "#{my_cards.join(' and ')} <===> #{test_ai.action}"
  
  # End the round to prepare for the next round
  test_ai.end_round
  
  # Stop the timer and add the elapsed time to the times array
  times << Time.now - start
end

# Find the average time elapsed to make a decision
average = times.inject(:+) / times.size

# Output the total and average time elapsed to make a decision, as well as the minimum and maximum times elapsed
puts "DONE!  Total time elapsed: #{times.inject(:+)}"
puts "#{average} seconds elapsed on average. (Lowest: #{times.min}, Highest: #{times.max})"