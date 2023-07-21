
using { /Fortnite.com/Devices }
using { /Fortnite.com/Characters }
using { /Fortnite.com/Playspaces }
using { /Verse.org/Simulation }
using { /Verse.org/Random }
using { /UnrealEngine.com/Temporary/Diagnostics }
using { /UnrealEngine.com/Temporary/SpatialMath }


# See https://dev.epicgames.com/documentation/en-us/uefn/create-your-own-device-in-verse for how to create a verse device.

# A Verse-authored creative device that can be placed in a level
multiplication_device := class(creative_device):

    MONSTER_MOVE_DISTANCE:float = 4000.0

    @editable Scoreboard : billboard_device = billboard_device{}

    @editable LeftAnswer : billboard_device = billboard_device{}
    @editable RightAnswer : billboard_device = billboard_device{}
    @editable TriggerRight:trigger_device = trigger_device{}
    @editable TriggerLeft:trigger_device = trigger_device{}

    @editable HudMessage : hud_message_device = hud_message_device{}
    @editable HudScore : hud_message_device = hud_message_device{}

    @editable Catty: creative_prop = creative_prop{}

    Monster: monster = monster{}

    var Score: int = 0
    var BestScore: int = 0

    var Question:question = question{Num1 := 0, Num2:= 0, LeftOption:= 0, RightOption:= 0}
    
    StringToMessage<localizes>(value:string) : message = "{value}"

    # Runs when the device is started in a running game
    OnBegin<override>()<suspends>:void=
        SetQuestion()
        TriggerRight.TriggeredEvent.Subscribe(OnTriggerdRight)
        TriggerLeft.TriggeredEvent.Subscribe(OnTriggerdLeft)
        HudMessage.SetDisplayTime(3.0)
        Monster.SetProp(Catty)
        Restart()

    ObserveMoster()<suspends>:void = 
        loop:
            moved:float = Monster.GetMovedDistance()
            if (moved > MONSTER_MOVE_DISTANCE):
                Finish()
                Sleep(7.0)
                Restart()
                break
            Sleep(0.5)
    
    Finish():void =
        DamagePlayer()
        ShowMessage("Finish!!! score : {Score}")
        UpdateBestScore()
        Monster.Finish()

    UpdateBestScore():void =
        if (Score > BestScore):
            set BestScore = Score
            HudScore.Hide()
            HudScore.SetText(StringToMessage("Best Score : {BestScore}"))
            HudScore.Show()


    Restart()<suspends>:void =
        set Score = 0
        ShowMessage("Shoot the correct answer!")
        spawn{ Monster.Start() }
        #Wait till Monster back to the original position
        Sleep(0.2)
        spawn{ ObserveMoster() }

    DamagePlayer():void =
        Playspace: fort_playspace = GetPlayspace()
        AllPlayers: []player = Playspace.GetPlayers()
        if (FirstPlayer : player = AllPlayers[0]):
            if (FortniteCharacter : fort_character = FirstPlayer.GetFortCharacter[]):
                MyCharacterHealth : float = FortniteCharacter.GetHealth()
                FortniteCharacter.Damage(MyCharacterHealth)

    SetQuestion():void =
        set Question = Question.NextQuestion()
        Scoreboard.SetText(StringToMessage("{Question.Num1} × {Question.Num2}"))
        LeftAnswer.SetText(StringToMessage("{Question.LeftOption}"))
        RightAnswer.SetText(StringToMessage("{Question.RightOption}"))

    OnTriggerdRight(MaybeAgent: ?agent) : void =
        if (Agent := MaybeAgent?):
            Validate(Question.RightOption, Agent)

    OnTriggerdLeft(MaybeAgent: ?agent) : void =
        if (Agent := MaybeAgent?):
            Validate(Question.LeftOption, Agent)

    ShowMessage(Message: string) : void =
        HudMessage.Hide()
        HudMessage.SetText(StringToMessage(Message))
        HudMessage.Show()

    Validate(UserAnswer: int, Agent: agent): void =
        Result:=Question.Validate(UserAnswer)
        if (Result?):
            set Score = Score + 10
            ShowMessage("Correct!! Score : {Score}")
            spawn{ Monster.Move(-400.0, 0.2) }
            SetQuestion()
            Monster.Accelerate()
        else:
            ShowMessage("Wrong")
            spawn{ Monster.Move(400.0, 0.2) }

monster := class:
    var MonsterProp: creative_prop = creative_prop{}
    var Speed: float = 100.0
    var OriginalPosition: vector3 = vector3{X:=0.0, Y:=0.0, Z:=0.0}
    var Finished: logic = false

    SetProp(NewProp: creative_prop):void =
        set MonsterProp = NewProp
        set OriginalPosition = MonsterProp.GetTransform().Translation

    Start()<suspends>: void =
        MonsterProp.MoveTo(OriginalPosition, MonsterProp.GetTransform().Rotation, 0.1 )
        set Finished = false
        set Speed = 100.0
        loop:
            if(Finished?):
                break
            else:
                Move(Speed, 0.5)
                Sleep(0.5)
    
    Accelerate(): void =
        if (Speed < 200.0):
            set Speed = Speed + 10.0
        else:
            set Speed = Speed + 2.0

    Finish(): void =
        set Finished = true

    GetMovedDistance(): float =
        Transform := MonsterProp.GetTransform()
        moved: float = Transform.Translation.Y - OriginalPosition.Y
        #Print("original={OriginalPosition.Y} current={Transform.Translation.Y} moved={moved}")
        return moved
       

    Move(Dist: float, Duration: float)<suspends>: void =
        Transform := MonsterProp.GetTransform()
        moved: float = Transform.Translation.Y - OriginalPosition.Y
        MonsterProp.MoveTo(Transform.Translation + vector3{X:=0.0, Y:=Dist, Z:=0.0}, Transform.Rotation, Duration)

question := class:
    Num1 : int
    Num2 : int
    LeftOption : int
    RightOption : int
        
    Validate(Selected: int) : logic = 
        if(Num1 * Num2 = Selected):
            true
        else:
            false

    NextQuestion(): question =
        LeftVal: int = GetRandomInt(1, 9)
        RightVal: int = GetRandomInt(1, 9)
        Correct: int = LeftVal * RightVal
        var Wrong: int = -1
        loop:
            set Wrong = Correct + GetRandomInt(-5, 5)
            if (not Wrong = Correct and Wrong > 0):
                break
        Options: []int = Shuffle(array {Correct, Wrong})

        var NewQ: question = question{Num1 := 1, Num2:= 1, LeftOption:= 1, RightOption:= 2}
        if (Left:int = Options[0]):
            if(Right:int = Options[1]):
                set NewQ = question{Num1 := LeftVal, Num2:= RightVal, LeftOption:= Left, RightOption:= Right}
        return NewQ

