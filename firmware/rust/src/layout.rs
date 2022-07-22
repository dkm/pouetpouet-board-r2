use keyberon::action::{k, l, m, Action::*, HoldTapConfig};
use keyberon::key_code::KeyCode::*;

type Action = keyberon::action::Action<CustomActions>;

#[derive(Debug, Clone, Copy, Eq, PartialEq)]
pub enum CustomActions {
    LightUp,
    LightDown,

    ModeCycle,
    ColorCycle,
    FreqUp,
    FreqDown,
}

pub static LU : CustomActions = CustomActions::LightUp;
pub static LD : CustomActions = CustomActions::LightDown;
pub static MC : CustomActions = CustomActions::ModeCycle;
pub static CC : CustomActions = CustomActions::ColorCycle;
pub static FU : CustomActions = CustomActions::FreqUp;
pub static FD : CustomActions = CustomActions::FreqDown;

#[cfg(not(feature = "testmode"))]
#[rustfmt::skip]

const D_ALT: Action = HoldTap {
    timeout: 200,
    tap_hold_interval: 0,
    config: HoldTapConfig::Default,
    hold: &k(LAlt),
    tap: &k(D),
};

const K_ALT: Action = HoldTap {
    timeout: 1000,
    tap_hold_interval: 0,
    config: HoldTapConfig::Default,
    hold: &k(RAlt),
    tap: &k(K),
};

const F_L1: Action = HoldTap {
    timeout: 200,
    tap_hold_interval: 0,
    config: HoldTapConfig::Default,
    hold: &l(1),
    tap: &k(F),
};

pub static LAYERS: keyberon::layout::Layers<12, 5, 2, CustomActions> = keyberon::layout::layout! {
    {
        [Kb1   Kb2 Kb3     Kb4    Kb5  Grave  Kb6  Kb7      Kb8     Kb9    Kb0    Minus]
        [Q     W   E       R      T    Tab    Y    U        I       O      P      LBracket]
        [A     S   D       F      G    BSpace H    J        K       L      SColon Quote]
        [Z     X   C       V      B    Enter  N    M        Comma   Dot    Slash  Bslash  ]
        [LCtrl (1) LGui    LShift LAlt Space  RAlt RBracket Equal   Delete RShift RCtrl]
    }
    {
        [F1          F2      F3 F4  F5 F6     F7     F8   F9     F10   F11     F12]
        [SysReq      NumLock t  t   t  Escape Insert PgUp PgDown VolUp VolDown Mute ]
        [t           t       t  t   t  t      Home   Up   End    t     t       t ]
        [NonUsBslash {Action::Custom(CC)} {Action::Custom(FU)} {Action::Custom(FD)} t t Left Down Right t t PgUp ]
        [{Action::Custom(LU)} t {Action::Custom(LD)} {Action::Custom(MC)} t t t t t t t PgDown]
    }
};

#[cfg(feature = "testmode")]
#[rustfmt::skip]
pub static LAYERS: keyberon::layout::Layers<CustomActions> = keyberon::layout::layout! {
    {
        [A, A, A, A, A, A, A, A, A, A, A, A],
        [A, A, A, A, A, A, A, A, A, A, A, A],
        [A, A, A, A, A, A, A, A, A, A, A, A],
        [A, A, A, A, A, A, A, A, A, A, A, A],
        [A, A, A, A, A, A, A, A, A, A, A, A],
    }
};

