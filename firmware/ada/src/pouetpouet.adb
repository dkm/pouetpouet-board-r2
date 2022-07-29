with STM32.Device; use STM32.Device;
with STM32.GPIO;    use STM32.GPIO;
with STM32.RCC; use STM32.RCC;

--  Temporary
-- with STM32_SVD.RCC; use STM32_SVD.RCC;
with STM32_SVD.TIM; use STM32_SVD.TIM;
with HAL; use HAL;

--  Not yet used.
-- with STM32.Timers;    use STM32.Timers;

with USB; use USB;
with USB.Device.HID.Keyboard;
with USB.Device; use USB.Device;

with Click;

with Logging; use Logging;

procedure Pouetpouet is

   Fatal_Error       : exception;

   type ColR is range 1 .. 12;
   type RowR is range 1 .. 5;

   type Rt is array (RowR) of GPIO_Point;
   type Ct is array (ColR) of GPIO_Point;

   Rows : constant Rt
     := [PB0, PB1, PB2, PB10, PB11];
   Cols : constant Ct
     := [PA0, PA1, PB13, PB12, PB14, PB15, PA15, PB3, PB4, PB5, PB8, PB9];

   package TestClick is new Click (5 ,ColR, RowR, GPIO_Point,
                                   Ct, Rt, Cols, Rows, 2, Logging.Log);
   use TestClick;

   Bepo_Layout : constant Layout :=
     [
      [
       [Kw (Kb1),   Kw (Kb2), Kw (Kb3),  Kw (Kb4),    Kw (Kb5),  Kw (Grave),  Kw (Kb6),  Kw (Kb7),      Kw (Kb8),   Kw (Kb9),    Kw (Kb0),    Kw (Minus)],
       [Kw (Q),     Kw (W),   Kw (E),    Kw (R),      Kw (T),    Kw (Tab),    Kw (Y),    Kw (U),        Kw (I),     Kw (O),      Kw (P),      Kw (Lbracket)],
       [Kw (A),     Kw (S),   Kw (D),    Kw (F),      Kw (G),    Kw (Bspace), Kw (H),    Kw (J),        Kw (K),     Kw (L),      Kw (Scolon), Kw (Quote)],
       [Kw (Z),     Kw (X),   Kw (C),    Kw (V),      Kw (B),    Kw (Enter),  Kw (N),    Kw (M),        Kw (Comma), Kw (Dot),    Kw (Slash),  Kw (Bslash)  ],
       [Kw (Lctrl), Lw (1),   Kw (Lgui), Kw (Lshift), Kw (Lalt), Kw (Space),  Kw (Ralt), Kw (Rbracket), Kw (Equal), Kw (Delete), Kw (Rshift), Kw (Rctrl)]
      ],

      [
        [Kw (F1),          Kw (F2),      Kw (F3), Kw (F4),  Kw (F5), Kw (F6),     Kw (F7),     Kw (F8),   Kw (F9),     Kw (F10),   Kw (F11),     Kw (F12)],
        [Kw (Sysreq),      Kw (Numlock), Kw (T),  Kw (T),   Kw (T),  Kw (Escape), Kw (Insert), Kw (Pgup), Kw (Pgdown), Kw (Volup), Kw (Voldown), Kw (Mute)],
        [Kw (T),           Kw (T),       Kw (T),  Kw (T),   Kw (T),  Kw (T),      Kw (Home),   Kw (Up),   Kw (Endd),   Kw (T),     Kw (T),       Kw (T)],
        [Kw (Nonusbslash), Kw (T),       Kw (T),  Kw (T),   Kw (T),  Kw (T),      Kw (Left),   Kw (Down), Kw (Right),  Kw (T),     Kw (T),       Kw (Pgup)],
        [Kw (T),           Kw (T),       Kw (T),  Kw (T),   Kw (T),  Kw (T),      Kw (T),      Kw (T),    Kw (T),      Kw (T),     Kw (T),       Kw (Pgdown)]
      ]
     ];

   Max_Packet_Size   : constant := 64;
   USB_Stack         : USB.Device.USB_Device_Stack (Max_Classes => 1);
   HID_Class : aliased USB.Device.HID.Keyboard.Instance;

   use type USB.Device.Init_Result;
   USB_Status  : USB.Device.Init_Result;

   procedure Dump_Events (Es : Events) is
   begin
      for E of Es loop
         Log (" - "
           & (if E.Evt = Press then "P " else "R ")
           & E.Row'Image & ":" & E.Col'Image);
       end loop;
   end Dump_Events;

   Rcc_Config : Rcc_Cfgr;
begin
   Testclick.Init;

   --  Clock config
   --  Currently only supports doing nothing (HSI) or using
   --  HSI48
   Set_Sys_Clock_Source (Rcc_Config, Hsi48);
   Enable_Crs (Rcc_Config);
   Set_Sys_Clock (Rcc_Config, 48_000_000);
   --  Set_P_Clock (Rcc_Config, 24_000_000);
   Freeze (Rcc_Config);

   if not USB_Stack.Register_Class (HID_Class'Unchecked_Access) then
      raise Fatal_Error with "Failed to register USB Serial device class";
   end if;

   USB_Status := USB_Stack.Initialize
     (Controller      => STM32.Device.UDC'Access,
      Manufacturer    => USB.To_USB_String ("Kataplop"),
      Product         => USB.To_USB_String ("Some buggy Keyboard"),
      Serial_Number   => USB.To_USB_String ("DEADBEEF"),
      Max_Packet_Size => Max_Packet_Size);

   if USB_Status /= USB.Device.Ok then
      raise Fatal_Error with "USB stack initialization failed: " & USB_Status'Image;
   end if;

   USB_Stack.Start;

   --  Using HAL to enable clock, but everything else is yet to be done.
   --  Using raw access to configure the timer until it's correctly
   --  implemented.
   Enable_Clock (Timer_1);

   --  1ms period
   TIM1_Periph.ARR.ARR := 1;
   TIM1_Periph.PSC.PSC := 48_000;
   TIM1_Periph.CR1.OPM := True;
   TIM1_Periph.CR1.UDIS := False;
   TIM1_Periph.CR1.DIR := True;

   Log ("STARTING FW");

   for Row of Keys.Rows loop
      Enable_Clock (Row);
      Configure_IO
        (Row,
         (Mode        => Mode_Out,
          Resistors   => Floating,
          Speed       => Speed_Medium,
          Output_Type => Push_Pull));
   end loop;

   for Col of Keys.Cols loop
      Enable_Clock (Col);
      Configure_IO
        (Col,
         (Mode        => Mode_In,
          Resistors   => Pull_Up));
   end loop;

   loop
      USB_Stack.Poll;

      TIM1_Periph.EGR.UG := True;
      TIM1_Periph.CR1.CEN := True;

      declare
         Evts : constant Events := Get_Events;
      begin
         --  FIXME: dot notation possible in GCC12
         if Evts'Length > 0 then
           Dump_Events(Evts);
           Register_Events (Bepo_Layout, Evts);
         end if;

         Tick (Bepo_Layout);

         for KC of Get_Key_Codes loop
            Log ("Got 1 keycode to push : " & Key_Code_T'Enum_Rep (KC)'Image);

            if HID_Class.Ready then
               HID_Class.Push_Key_Code (Key_Code_T'Enum_Rep (KC));
            end if;
         end loop;

         for M of Get_Modifiers loop
              HID_Class.Set_Modifier (M, True);
         end loop;

         HID_Class.Send_Report (UDC);
      end;

      --  Not clear why the timers stops at 1 instead of 0
      while Tim1_Periph.CNT.CNT > 1 loop
        null;
      end loop;
   end loop;
end Pouetpouet;
