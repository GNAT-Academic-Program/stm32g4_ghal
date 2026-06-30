with I2C_Types;
with STM32G431xx;
with STM32G431xx.I2C;
with System.Storage_Elements; use System.Storage_Elements;

--  STM32G431_I2C models a physical I2C bus (I2C1, I2C2, etc.).
--  The instantiation IS the bus. There is no Device type.
--
--  Device-level abstractions (chip address, state) belong in chip drivers,
--  not here.

generic
   Periph         : not null access STM32G431xx.I2C.I2C_Peripheral;
   with function  Get_Clock return Natural;
   with procedure RCC_Enable;
   with procedure RCC_Reset;
package STM32G431_I2C is

   --  Control-plane hooks

   procedure Init    (Cfg : I2C_Types.I2C_Config);
   procedure Enable;
   procedure Disable;
   procedure Reset;
   procedure Recover;
   procedure Probe   (Target : I2C_Types.I2C_Address;
                      Result : out I2C_Types.Ack_State);

   --  Data-plane hooks

   procedure Begin_Write (Target : I2C_Types.I2C_Address;
                          Length : Natural;
                          Stop   : Boolean);
   procedure Begin_Read  (Target : I2C_Types.I2C_Address;
                          Length : Natural;
                          Stop   : Boolean);
   procedure Send        (B   : Storage_Element);
   procedure Recv        (B   : out Storage_Element;
                          Ack : Boolean);

end STM32G431_I2C;