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
                                   Ct, Rt, Cols, Rows);
   use TestClick;

   BepoLayout : constant Layout :=
     [
      [Kb1,   Kb2, Kb3,  Kb4,    Kb5,  Grave,  Kb6,  Kb7,      Kb8,   Kb9,    Kb0,    Minus],
      [Q,     W,   E,    R,      T,    Tab,    Y,    U,        I,     O,      P,      LBracket],
      [A,     S,   D,    F,      G,    BSpace, H,    J,        K,     L,      SColon, Quote],
      [Z,     X,   C,    V,      B,    Enter,  N,    M,        Comma, Dot,    Slash,  Bslash  ],
      [LCtrl, X,        LGui, LShift, LAlt, Space,  RAlt, RBracket, Equal, Delete, RShift, RCtrl]
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
         for Evt of Evts loop
            Log ("(" & Evt.Evt'Image & ", " & Evt.Col'Image & ", "
                   & Evt.Row'Image & ") = "
                   & KeyCode'Enum_Rep (BepoLayout (Evt.Row, Evt.Col))'Image);

            if HID_Class.Ready then
               if Evt.Evt = Press then
                  HID_Class.Push_Key_Code
                    (KeyCode'Enum_Rep (BepoLayout (Evt.Row, Evt.Col)));
               end if;

               HID_Class.Send_Report (UDC);
            end if;
         end loop;
      end;
      --      Delay_Cycles (72);
   end loop;
end Pouetpouet;
