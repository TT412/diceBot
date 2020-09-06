#--*-coding:utf-8-*--

class Nssq < DiceBot
  
  def initialize
    super
    
    @sendMode = 2 #(0=結果のみ,1=0+式,2=1+ダイス個別)
    @sortType = 1;      #ソート設定(1 = ?, 2 = ??, 3 = 1&2　各値の意味が不明です…）
    # @sameDiceRerollCount = 0;     #ゾロ目で振り足し(0=無し, 1=全部同じ目, 2=ダイスのうち2個以上同じ目)
    # @sameDiceRerollType = 0;   #ゾロ目で振り足しのロール種別(0=判定のみ, 1=ダメージのみ, 2=両方)
    # @d66Type = 0;        #d66の差し替え
    # @isPrintMaxDice = false;      #最大値表示
    # @upplerRollThreshold = 0;      #上方無限
    # @unlimitedRollDiceType = 0;    #無限ロールのダイス
    # @rerollNumber = 0;      #振り足しする条件
    # @defaultSuccessTarget = "";      #目標値が空欄の時の目標値
    # @rerollLimitCount = 0;    #振り足し回数上限
    # @fractionType = "omit";     #端数の処理 ("omit"=切り捨て, "roundUp"=切り上げ, "roundOff"=四捨五入)
  end
  
  
  def prefixs
    #ダイスボットで使用するコマンドを配列で列挙すること。
    ['\d+SQ([\+\-\d]*)','\d+DR(C)?(\+)?\d+','(T|S|G)C.*','\d+HR\d*']
  end
  
  def gameName
    'SRSじゃない世界樹の迷宮TRPG'
  end
  
  def gameType
    "Nssq"
  end
 
  def getHelpMessage
    return <<MESSAGETEXT
・判定(xSQ±y)
  xD6の判定。3つ以上振ったとき、出目の高い2つを表示します。クリティカル、ファンブルも計算します。
  ±y: yに修正値を入力。±の計算に対応。省略可能。
・ダメージロール(xDR(C)(+)y)
  xD6のダメージロール。クリティカルの自動判定を行います。Cを付けるとクリティカルアップ状態で計算できます。+を付けるとクリティカル時のダイスが8個になります
  x: xに振るダイス数を入力。
  y: yに耐性を入力。
  例) 5DR3 5DRC4 5DRC+4
・回復ロール(xHRy)
　xD6の回復ロール。クリティカルが発生しません。
　x: xに振るダイス数を入力。
  y: yに耐性を入力。メディックの集中治療使用時以外は原則3。省略した場合3。
　例) 2HR 10HR
・採取ロール(TC±z,SC±z,GC±z)
  ちょっと(T)、そこそこ(S)、がっつり(G)採取採掘伐採を行う。
  z: zに追加でロールする回数を入力。省略可能。
  例) TC SC+1 GC-1
MESSAGETEXT
  end
  
  def changeText(string)
    string
  end
  
  def rollDiceCommand(command)
                                                                       
   # get～DiceCommandResultという名前のメソッドを集めて実行、
   # 結果がnil以外の場合それを返して終了。
   
   methodList = public_methods(false).select do |method|
     method.to_s =~ /\Aget.+DiceCommandResult\z/
   end
   
   methodList.each do |method|
     result = send(method, command)
     return result unless result.nil?
   end
   
   return nil
  end

  def getRollDiceCommandResult(command)

    return nil unless(/(\d)SQ([\+\-\d]*)/i === command)

    diceCount = $1.to_i
    modifyText = ($2 || '')
    modify = getValue(modifyText,0)
    crifanText = ''

    #ダイスロールして、結果を降順にソート
    dice, dice_str, = roll(diceCount, 6)
    diceList = dice_str.split(/,/).collect{|i|i.to_i}.sort {|a, b|b <=> a}

    #長さが2以上の場合先頭の2つを切り出し、合計値を算出
    if(diceList.size >= 2)
      diceList = diceList.slice(0, 2)
      dice = diceList[0] + diceList[1]
    end

    #クリティカル、ファンブルを判定
    if(diceList[0] == diceList[1])
      if(diceList[0] == 6)
        crifanText = " クリティカル！"
      end
      if(diceList[0] == 1)
        crifanText = " ファンブル！"
      end
    end

    #修正値を加算
    dice += modify

    #出力用文の生成
    result = "(#{command}) ＞ [#{dice_str}]#{modifyText} ＞ #{dice}[#{diceList.join(",")}]" + crifanText

    return result

  end

  def getValue(text,defaultValue)
    return defaultValue if(text == nil or text.empty?)

    parren_killer("(0" + text + ")").to_i
  end

  def getDamegeRollDiceCommandResult(command)

    #ダメージロール
    return nil unless(/(\d+)DR(C)?(\+)?(\d+)/i === command)

    diceCount = $1.to_i
    criticalText = ($2 || '')
    plusText = ($3 || '')
    resist = $4.to_i

    #ダイスロール
    _dice, dice_str, = roll(diceCount, 6)
    diceList = dice_str.split(/,/).collect{|i|i.to_i}.sort

    #出力文の生成
    result = makeCommand(diceCount, diceList, dice_str, criticalText, plusText, resist)

    #クリティカルチェック
    #クリティカルアップ状態かどうかを判定
    if(criticalText == '')
      if(numCheck(diceList, 6) >= numCheck(diceList, 1) + 2)
        result += "クリティカル！\n"
        result += criticalPlus(plusText, resist)
      end
    else
      if(numCheck(diceList, 6) >= numCheck(diceList, 1) + 1)
        result += "クリティカル！\n"
        result += criticalPlus(plusText, resist)
      end
    end

    return result

  end

  def getHealRollDiceCommandResult(command)

    #回復ロール
    return nil unless(/(\d+)HR(\d*)/i === command)

    diceCount = $1.to_i
    resist = $2
    if(resist == '')
      resist = 3
    else
      resist = resist.to_i
    end

    #ダイスロール
    _dice, dice_str, = roll(diceCount, 6)
    diceList = dice_str.split(/,/).collect{|i|i.to_i}.sort

    #出力文の生成
    result = "(#{command}) ＞ [#{dice_str}]#{resist} ＞ " + damageCheck(diceList, resist).to_s + "回復"

    return result

  end

  def makeCommand(diceCount, diceList, dice_str, criticalText, plusText, resist)
    #出力用ダイスコマンドを生成
    command = "#{diceCount}DR" + criticalText + plusText + "#{resist}"

    #出力文の生成
    result = "(#{command}) ＞ [#{dice_str}]#{resist} ＞ "

    damage = damageCheck(diceList, resist)

    result += damage.to_s + "ダメージ "

    return result
  end

  def numCheck(diceList, num)
    return(diceList.select{|i|i == num}.size)
  end

  def damageCheck(diceList, resist)
    
    #ダメージ計算
    damage = diceList.select{|i|i > resist}.size

    return damage
  end

  def criticalPlus(plusText, resist)
  #クリティカル時に4つダイスを振るか8つダイスを振るか判定し、ダメージロール
    if(plusText == '')
      diceCount = 4
    else
      diceCount = 8
    end
    _dice, dice_str, = roll(diceCount, 6)
    diceList = dice_str.split(/,/).collect{|i|i.to_i}.sort

    result = makeCommand(diceCount, diceList, dice_str, '', '', resist)

    return result
  end

  def getCollectDiceCommandResult(command)
    #採取表

    return nil unless(/(T|S|G)C([\+\-\d]*)/i === command)

    type = $1
    modify = ($2 || 0).to_i

    #ああっと値の設定
    case type
      when "T"
        aattoParam = 3
      when "S"
        aattoParam = 4
      when "G"
        aattoParam = 5
      else
        return nil
    end
    if((aattoParam - 2 + modify) <= 0)
      return nil
    end

    #ダイスロール
    i = 0
    result = ""
    while i < (aattoParam - 2 + modify) do
      dice, dice_str = roll(2, 6)

      #出力用文の生成
      result += "(#{command}) ＞ #{dice}[#{dice_str}]: "

      #！ああっと！の判定
      if((dice <= aattoParam) && (aattoParam - 2 > i))
        result += "！ああっと！"
      else
        result += "成功"
        if(aattoParam - 2 <=i)
          result += "（追加分）"
        end
      end
      result += "\n"
      i += 1
    end
    #末尾の改行文字を削除
    result.chomp!

    return result
  end
  
  #getDiceList を呼び出すとロース結果のダイス目の配列が手に入ります。
end
