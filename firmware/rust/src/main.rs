#![no_main]
#![no_std]

// set the panic handler
use panic_halt as _;

use core::convert::Infallible;
use keyberon::action::{k, l, Action::*, HoldTapConfig};
use keyberon::key_code::KeyCode::*;
use keyberon::layout::{Event, Layout};

use keyberon::matrix::Matrix;
use rtic::app;
use stm32f0xx_hal as hal;
use usb_device::bus::UsbBusAllocator;
use usb_device::class::UsbClass as _;
use usb_device::device::UsbDeviceState;

extern crate smart_leds;
extern crate ws2812_spi;
use smart_leds::{brightness, colors, SmartLedsWrite, RGB8};

use ws2812_spi as ws2812;

use hal::delay::Delay;
use hal::gpio::{gpioa, Alternate, Input, Output, Pin, PullUp, PushPull, AF0};
use hal::prelude::*;

mod layout;
use layout::CustomActions;

use embedded_hal::spi::FullDuplex;

use hal::usb;
use hal::{
    spi::{EightBit, Mode, Phase, Polarity},
    stm32, timers,
};

use keyberon::debounce::Debouncer;
use keyberon::key_code::KbHidReport;

type Spi = hal::spi::Spi<
    stm32::SPI1,
    gpioa::PA5<Alternate<AF0>>,
    gpioa::PA6<Alternate<AF0>>,
    gpioa::PA7<Alternate<AF0>>,
    EightBit,
>;

type UsbClass = keyberon::Class<'static, usb::UsbBusType, Leds<Spi>>;

type UsbDevice = usb_device::device::UsbDevice<'static, usb::UsbBusType>;

trait ResultExt<T> {
    fn get(self) -> T;
}
impl<T> ResultExt<T> for Result<T, Infallible> {
    fn get(self) -> T {
        match self {
            Ok(v) => v,
            Err(e) => match e {},
        }
    }
}

pub const NUM_LEDS: u8 = 4+12*5;
pub struct Leds<SPI> {
    ws: ws2812::Ws2812<SPI>,
    leds: [RGB8; NUM_LEDS as usize],
}

impl<SPI, E> Leds<SPI>
    where
        SPI: FullDuplex<u8, Error = E>,
{
    fn keys_set(&mut self, line: u8, col: u8, status: bool) {

        //  ,- 3, 2, 1, 0] <- Array LEDs starts on status, from the right.
        //  |
        //  `----------------------------------------------------,
        //                                                       |
        //  ,-- 15, 14, 13, 12, 11, 10,  9,  8,  7,  6,  5,  4, <'  line 0
        //  |
        //  `-> 16, 17, 18, 19, 20, 21, 22, 23, 24, 25, 26, 27,...  line 1
        //
        //  col: 0   1   2   3   4   5   6   7   8   9  10  11

        let coord = (4 + (line * 12) + (if line%2 != 0 {11-col} else {col})) as usize;

        if status {
            self.leds[coord] = colors::BLUE;
        } else {
            self.leds[coord] = colors::BLACK;
        }
    }

    fn refresh(&mut self) {
        if self.ws.write(brightness(self.leds.iter().cloned(), NUM_LEDS)).is_err() {
            panic!();
        }
    }
}

impl<SPI, E> keyberon::keyboard::Leds for Leds<SPI>
where
    SPI: FullDuplex<u8, Error = E>,
{
    fn caps_lock(&mut self, status: bool) {
        if status {
            self.leds[0] = colors::BLUE;
        } else {
            self.leds[0] = colors::BLACK;
        }
        if self.ws.write(brightness(self.leds.iter().cloned(), NUM_LEDS)).is_err() {
            panic!();
        }
    }

    fn num_lock(&mut self, status: bool) {
        if status {
            self.leds[1] = colors::GREEN;
        } else {
            self.leds[1] = colors::BLACK;
        }
        if self.ws.write(brightness(self.leds.iter().cloned(), NUM_LEDS)).is_err() {
            panic!();
        }
    }

    fn compose(&mut self, status: bool) {
        if status {
            self.leds[3] = colors::VIOLET;
        } else {
            self.leds[3] = colors::BLACK;
        }
        if self.ws.write(brightness(self.leds.iter().cloned(), NUM_LEDS)).is_err() {
            panic!();
        }

    }
}

#[derive(Debug, Clone, Copy, Eq, PartialEq)]
pub enum BacklightMode {
    Off,
    Solid(RGB8),
    Circling(RGB8, usize, usize, usize, bool),
    Breath(RGB8, usize, usize, bool),
}

pub struct Backlight {
    mode: BacklightMode,
    brightness: u8,
}

trait ColorSeq {
    fn next_color(&self) -> RGB8;
}

const COLORS_SEQ: [RGB8; 5] = [
    colors::RED,
    colors::GREEN,
    colors::BLUE,
    colors::VIOLET,
    colors::YELLOW,
];

impl ColorSeq for RGB8 {
    fn next_color(&self) -> RGB8 {
        let mut next = false;

        for c in &COLORS_SEQ {
            if next {
                return *c;
            }

            if *self == *c {
                next = true;
            }
        }

        COLORS_SEQ[0]
    }
}

impl Backlight {
    pub fn next_mode(&mut self) {
        self.mode = match self.mode {
            BacklightMode::Off => BacklightMode::Solid(colors::RED),
            BacklightMode::Solid(_) => BacklightMode::Circling(colors::RED, 100, 0, 0, true),
            BacklightMode::Circling(_, _, _, _, _) => {
                BacklightMode::Breath(colors::RED, 10, 0, true)
            }
            BacklightMode::Breath(_, _, _, _) => BacklightMode::Off,
        }
    }

    pub fn change_freq(&mut self, up: bool) {
        self.mode = match self.mode {
            BacklightMode::Breath(c, tstep, step, dir) => {
                let tstep = if up {
                    if tstep - 10 > 10 {
                        tstep - 10
                    } else {
                        10
                    }
                } else if tstep + 10 < 1000 {
                    tstep + 10
                } else {
                    1000
                };
                BacklightMode::Breath(c, tstep, step, dir)
            }
            BacklightMode::Circling(c, tstep, step, i, dir) => {
                let tstep = if up {
                    if tstep - 10 > 10 {
                        tstep - 10
                    } else {
                        10
                    }
                } else if tstep + 10 < 1000 {
                    tstep + 10
                } else {
                    1000
                };
                BacklightMode::Circling(c, tstep, step, i, dir)
            }
            any => any,
        }
    }

    pub fn next_color(&mut self) {
        self.mode = match self.mode {
            BacklightMode::Solid(c) => BacklightMode::Solid(c.next_color()),
            BacklightMode::Breath(c, tstep, step, dir) => {
                BacklightMode::Breath(c.next_color(), tstep, step, dir)
            }
            BacklightMode::Circling(c, ts, s, i, dir) => {
                BacklightMode::Circling(c.next_color(), ts, s, i, dir)
            }
            any => any,
        }
    }

    pub fn refresh_leds(&mut self, leds: &mut Leds<Spi>) {
        self.mode = match self.mode {
            BacklightMode::Off => {
                for l in leds.leds[4..].iter_mut() {
                    *l = colors::BLACK;
                }
                BacklightMode::Off
            }

            BacklightMode::Solid(c) => {
                for l in leds.leds[4..].iter_mut() {
                    *l = c;
                }
                BacklightMode::Solid(c)
            }

            BacklightMode::Breath(c, tstep, step, dir) => {
                let mut step = step + 1;
                let mut new_dir = dir;

                if step >= tstep {
                    step = 0;

                    for l in leds.leds[4..].iter_mut() {
                        *l = c;
                    }

                    if dir {
                        if self.brightness == 100 {
                            self.brightness -= 1;
                            new_dir = false;
                        }
                        self.brightness += 1;
                    } else {
                        if self.brightness == 5 {
                            self.brightness += 1;
                            new_dir = true;
                        }
                        self.brightness -= 1;
                    }
                }

                BacklightMode::Breath(c, tstep, step, new_dir)
            }

            BacklightMode::Circling(c, tstep, step, index, dir) => {
                let mut new_dir = dir;
                let mut new_index = index;

                let mut step = step + 1;

                if step >= tstep {
                    step = 0;

                    if new_index == 0 && !dir {
                        new_index = 0;
                        new_dir = true;
                    } else if new_index == 6 && dir {
                        new_index = 6;
                        new_dir = false;
                    } else {
                        new_index = if dir { index + 1 } else { index - 1 };
                    }
                }

                for (i, l) in leds.leds[4..].iter_mut().enumerate() {
                    let ni = if new_index == 0 { 5 } else { new_index - 1 };
                    if i == ni {
                        *l = c;
                    } else {
                        *l = colors::BLACK;
                    }
                }
                BacklightMode::Circling(c, tstep, step, new_index as usize, new_dir)
            }
        };

        if leds.ws
            .write(brightness(leds.leds.iter().cloned(), self.brightness)).is_err() {
                panic!();
            }
    }
}


#[app(device = crate::hal::pac, peripherals = true, dispatchers = [CEC_CAN, SPI2])]
mod app {
    use super::*;

    #[shared]
    struct Shared {
        usb_dev: UsbDevice,
        usb_class: UsbClass,

        #[lock_free]
        layout: Layout<12, 5, 2, CustomActions>,

        #[lock_free]
        backlight: Backlight,
    }

    #[local]
    struct Local {
        matrix: Matrix<Pin<Input<PullUp>>, Pin<Output<PushPull>>, 12, 5>,
        debouncer: Debouncer<[[bool; 12]; 5]>,
        timer: timers::Timer<stm32::TIM3>,
    }

    #[init(local = [bus: Option<UsbBusAllocator<usb::UsbBusType>> = None])]
    fn init(mut c: init::Context) -> (Shared, Local, init::Monotonics) {

        let mut rcc = c
            .device
            .RCC
            .configure()
            .hsi48()
            .enable_crs(c.device.CRS)
            .sysclk(48.mhz())
            .pclk(24.mhz())
            .freeze(&mut c.device.FLASH);

        let gpioa = c.device.GPIOA.split(&mut rcc);
        let gpiob = c.device.GPIOB.split(&mut rcc);

        let usb = usb::Peripheral {
            usb: c.device.USB,
            pin_dm: gpioa.pa11,
            pin_dp: gpioa.pa12,
        };

        *c.local.bus = Some(usb::UsbBusType::new(usb));
        let usb_bus = c.local.bus.as_ref().unwrap();

        // Handling of ws2812 leds

        let pa5 = gpioa.pa5; // sck
        let pa6 = gpioa.pa6; // miso
        let pa7 = gpioa.pa7; // mosi

        // Configure pins for SPI
        let (sck, miso, mosi) = cortex_m::interrupt::free(move |cs| {
            (
                pa5.into_alternate_af0(cs),
                pa6.into_alternate_af0(cs),
                pa7.into_alternate_af0(cs),
            )
        });

        const MODE: Mode = Mode {
            polarity: Polarity::IdleHigh,
            phase: Phase::CaptureOnSecondTransition,
        };
        let spi = Spi::spi1(
            c.device.SPI1,
            (sck, miso, mosi),
            MODE,
            3_000_000.hz(),
            &mut rcc,
        );

        // ws2812
        let mut ws = ws2812::Ws2812::new(spi);

        // Do a simple smooth blink at start
        let mut delay = Delay::new(c.core.SYST, &rcc);
        let tmpleds = [colors::GREEN; NUM_LEDS as usize];
        for i in (0..100).chain((0..100).rev()) {
            ws.write(brightness(tmpleds.iter().cloned(), i)).unwrap();
            delay.delay_ms(5u8);
        }

        let mut leds = Leds {
            ws,
            leds: [colors::BLACK; NUM_LEDS as usize],
        };

        leds.ws.write(leds.leds.iter().cloned()).unwrap();

        let usb_class = keyberon::new_class(usb_bus, leds);
        let usb_dev = keyberon::new_device(usb_bus);

        let mut timer = timers::Timer::tim3(c.device.TIM3, 1.khz(), &mut rcc);
        timer.listen(timers::Event::TimeOut);

        let pa0 = gpioa.pa0;
        let pa10 = gpioa.pa10;
        let pa15 = gpioa.pa15;

        let matrix = cortex_m::interrupt::free(move |cs| {
            Matrix::new(
                [
                    pa0.into_pull_up_input(cs).downgrade(),
                    gpiob.pb12.into_pull_up_input(cs).downgrade(),
                    gpiob.pb13.into_pull_up_input(cs).downgrade(),
                    gpiob.pb14.into_pull_up_input(cs).downgrade(),
                    gpiob.pb15.into_pull_up_input(cs).downgrade(),
                    pa10.into_pull_up_input(cs).downgrade(),
                    pa15.into_pull_up_input(cs).downgrade(),
                    gpiob.pb3.into_pull_up_input(cs).downgrade(),
                    gpiob.pb4.into_pull_up_input(cs).downgrade(),
                    gpiob.pb5.into_pull_up_input(cs).downgrade(),
                    gpiob.pb8.into_pull_up_input(cs).downgrade(),
                    gpiob.pb9.into_pull_up_input(cs).downgrade(),
                ],
                [
                    gpiob.pb0.into_push_pull_output(cs).downgrade(),
                    gpiob.pb1.into_push_pull_output(cs).downgrade(),
                    gpiob.pb2.into_push_pull_output(cs).downgrade(),
                    gpiob.pb10.into_push_pull_output(cs).downgrade(),
                    gpiob.pb11.into_push_pull_output(cs).downgrade(),

                ],
            )});

        (
            Shared {
                usb_dev,
                usb_class,
                layout: Layout::new(&crate::layout::LAYERS),
                backlight: Backlight {
                    mode: BacklightMode::Off,
                    brightness: 8,
                },
            },

            Local {
                timer,
                debouncer: Debouncer::new([[false; 12]; 5], [[false; 12]; 5], 5),
                matrix: matrix.get(),
            },
            init::Monotonics(),
        )
    }

    #[task(binds = USB, priority = 3, shared = [usb_dev, usb_class])]
    fn usb_rx(c: usb_rx::Context) {
        (c.shared.usb_dev, c.shared.usb_class).lock(|usb_dev, usb_class| {
            if usb_dev.poll(&mut [usb_class]) {
                usb_class.poll();
            }
        });
    }

    #[task(priority = 2, shared = [usb_dev, usb_class, layout, backlight])]
    fn tick_keyberon(mut c: tick_keyberon::Context) {
        let tick = c.shared.layout.tick();
        if c.shared.usb_dev.lock(|d| d.state()) != UsbDeviceState::Configured {
            return;
        }
        // match tick {
        //     CustomEvent::Release(()) => unsafe { cortex_m::asm::bootload(0x1FFFC800 as _) },
        //     _ => (),
        // }

        match tick {
            keyberon::layout::CustomEvent::Release(CustomActions::LightUp) => {
                let bl_val = &mut c.shared.backlight.brightness;
                *bl_val = if *bl_val == 100 { 100 } else { *bl_val + 1 };
                c.shared.usb_class.lock(|k| {
                    let leds = k.device_mut().leds_mut();
                    if leds.ws
                        .write(brightness(leds.leds.iter().cloned(), *bl_val)).is_err() {
                            panic!();
                        }
                });
            }
            keyberon::layout::CustomEvent::Release(CustomActions::LightDown) => {
                let bl_val = &mut c.shared.backlight.brightness;
                *bl_val = if *bl_val == 0 { 0 } else { *bl_val - 1 };
                c.shared.usb_class.lock(|k| {
                    let leds = k.device_mut().leds_mut();
                    if leds.ws
                        .write(brightness(leds.leds.iter().cloned(), *bl_val)).is_err() {
                            panic!();
                        }
                });
            }
            keyberon::layout::CustomEvent::Release(CustomActions::ColorCycle) => {
                c.shared.backlight.next_color();
            }
            keyberon::layout::CustomEvent::Release(CustomActions::ModeCycle) => {
                c.shared.backlight.next_mode();
            }
            keyberon::layout::CustomEvent::Release(CustomActions::FreqUp) => {
                c.shared.backlight.change_freq(true);
            }
            keyberon::layout::CustomEvent::Release(CustomActions::FreqDown) => {
                c.shared.backlight.change_freq(false);
            }
            _ => (),
        }

        let report: KbHidReport = c.shared.layout.keycodes().collect();
        if !c
            .shared
            .usb_class
            .lock(|k| k.device_mut().set_keyboard_report(report.clone()))
        {
            return;
        }
        while let Ok(0) = c.shared.usb_class.lock(|k| k.write(report.as_bytes())) {}
    }

    #[task(priority = 2, capacity = 8, shared = [layout])]
    fn handle_event(c: handle_event::Context, event: Event) {
        c.shared.layout.event(event)
    }

    #[task(priority = 1, capacity = 16, shared = [usb_class])]
    fn handle_led_matrix(mut c: handle_led_matrix::Context, event: Event) {
        c.shared.usb_class.lock(|k| {
            let leds = k.device_mut().leds_mut();
            match event {
                Event::Press(line, col) => leds.keys_set(line, col, true),
                Event::Release(line, col) => leds.keys_set(line, col, false),
            }
        });
    }

    #[task(priority = 1, capacity = 8, shared = [usb_class])]
    fn refresh_led_matrix(mut c: refresh_led_matrix::Context) {
        c.shared.usb_class.lock(|k| {
            let leds = k.device_mut().leds_mut();
            leds.refresh();
        });
    }

    #[task(
        binds = TIM3,
        priority = 1,
        local = [matrix, debouncer, timer],
    )]
    fn tick(c: tick::Context) {
        c.local.timer.wait().ok();

        for event in c
            .local
            .debouncer
            .events(c.local.matrix.get().get())
        {
            // Better would be to reset all LEDs on error to avoid any strange setuprrr
            handle_led_matrix::spawn(event).unwrap_or_default();
            handle_event::spawn(event).unwrap();
        }

        // will be refresh when slot available
        refresh_led_matrix::spawn().unwrap_or_default();

        tick_keyberon::spawn().unwrap();
    }
}
