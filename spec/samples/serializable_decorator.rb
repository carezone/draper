class SerializableDecorator < Draper::Base
  decorates :serializable
  serializes :deco, :foo, {:bar_renamed => :bar}, {:literal => "Literal"}

  def deco
    "deco"
  end
end
