# Third-party notices

The Skill references these public upstream projects for API discovery, compatibility checks, and testing patterns:

- [Hotwire Native iOS](https://github.com/hotwired/hotwire-native-ios), MIT License
- [Hotwire Native Android](https://github.com/hotwired/hotwire-native-android), MIT License
- [Hotwire Native Bridge](https://github.com/hotwired/hotwire-native-bridge), MIT License
- [Turbo Rails](https://github.com/hotwired/turbo-rails), MIT License
- [Action Push Native](https://github.com/rails/action_push_native), MIT License
- [Bridge Components](https://github.com/joemasilotti/bridge-components), MIT License for its public repository

The bundled bridge-form template includes adaptations of MIT-licensed examples from Bridge Components v0.13.2, Hotwire Native iOS 1.3.0, and Hotwire Native Android 1.3.0. Its web controller is derived from the licensed Bridge Components implementation—not the similarly structured, unlicensed `hotwired/hotwire-native-demo` example. Exact source commits are recorded in [`upstream-lock.yml`](upstream-lock.yml). Required notices are preserved beside the template in [`LICENSES.md`](skills/develop-hotwire-native/assets/templates/bridge-form/LICENSES.md), and every adapted file identifies its source and copyright holder in a header.

The repository may discuss patterns observed in other public or purchased materials, but it does not include their prose or restricted source code. In particular, it does not redistribute:

- *Hotwire Native for Rails Developers* or paid newsletter text;
- Bridge Components PRO source;
- substantial Fizzy source code governed by the O'Saasy License.

All product and project names belong to their respective owners. Inclusion here does not imply endorsement.
