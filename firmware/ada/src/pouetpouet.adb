with STM32.Device; use STM32.Device;
with STM32.GPIO;    use STM32.GPIO;

--  Not yet used.
--  with STM32.Timers;    use STM32.Timers;

--  with USB.HAL.Device;
--  with USB.Device.Serial;

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
                                   Ct, Rt, Cols, Rows, 2);
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

begin
   Init;

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

   --  Enable_Clock (Timer_1);
   --  Reset (Timer_1);

   --  Configure (Timer_1, Prescaler => 13999, Period => 5999);

   --  Enable_Interrupt (Timer_1, Timer_Update_Interrupt);

   --  Enable (Timer_1);
   Log ("STARTING");

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

      declare
         Evts : constant Events := Get_Events (Get_Matrix);
      begin
         --  FIXME: dot notation possible in GCC12
         Register_Events (Bepo_Layout, Evts);
         Tick (Bepo_Layout);

         for KC of Key_Codes (Bepo_Layout) loop
            --  Log ("(" & Evt.Evt'Image & ", " & Evt.Col'Image & ", "
            --         & Evt.Row'Image & ") = "
            --         & Key_Code_T'Enum_Rep (Bepo_Layout (Evt.Row, Evt.Col).C)'Image);

            if HID_Class.Ready then
               --  if Evt.Evt = Press then
               --  HID_Class.Push_Key_Code
               --    (Key_Code_T'Enum_Rep (Bepo_Layout (Evt.Row, Evt.Col).C));
               HID_Class.Push_Key_Code (Key_Code_T'Enum_Rep (KC));

               --  end if;
            end if;
         end loop;
         HID_Class.Send_Report (UDC);
      end;
      --      Delay_Cycles (72);
   end loop;
end Pouetpouet;
