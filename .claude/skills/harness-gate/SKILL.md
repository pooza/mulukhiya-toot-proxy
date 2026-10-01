---
name: harness-gate
description: chubo2 の fedi-test-harness で develop を Mastodon 系・Misskey 系の両方で実走するリリースゲートと、upstream（Mastodon / Misskey）の新しい版の互換性検証。リリース前、または同期で新しい upstream 版を見つけたときに使う。
---

# harness 実走（リリースゲート）と upstream 版の検証

⚠ この手順の正本はこのファイル（#4731 で `docs/test-harness.md` と `docs/harness-verified-versions.yaml` の冒頭から移した）。
harness の仕組み・起動・後片付けは [test-harness.md](../../../docs/test-harness.md) を読む。
⚠⚠ **使い終わったらすぐ teardown する**（`test-harness.md`「後片付け」）。

## リリースゲートとしての実走（省略不可）

**この実走はリリース手順の必須ステップ**（`release` スキルの手順 4）。
CI には実サーバーが無く、アカウント依存のテスト 300 件超が omission のまま
`100% passed` と出るため、**CI の緑はこのゲートの代わりにならない**（#4503）。

### ⚠ 系ごとにシェルを分ける（同じシェルで両系を source しない）

`source .env.test` した変数は**シェルに残る**。Mastodon → Misskey の順に同じシェルで
source すると `MASTODON_*` と `MISSKEY_*` が両方揃い、コントローラ選択は
`config['/controller']`（既定 `mastodon`）に倒れる。つまり **Misskey のつもりで
Mastodon をもう一度走らせたまま「両系緑」とゲートを通せてしまう**（#4559）。

- 系ごとに**別のシェル**（別タブ・`bash -c` の中・`env -i`）で回す
  - ⚠ **`env -i` を使うなら `LANG` / `LC_ALL` を残す**（2026-08-11 に踏んだ）。落とすと Ruby の
    外部エンコーディングが US-ASCII になり、**製品と無関係な
    `invalid byte sequence in US-ASCII` が 1 failures / 5 errors 出る**。退行と読み違える。
    `env -i HOME="$HOME" PATH="$PATH" TERM=dumb LANG="$LANG" LC_ALL="$LC_ALL" bash -c ...` で足りる
  - 分離できたかは実走の前に `env | grep -c '^MASTODON_'` などで数えると確実（0 であること）
- 実走の頭で `TestHarness` が **選択したコントローラを stderr に出す**ので、source した
  `.env.test` と一致しているかを毎回見る:

  ```text
  TestHarness: controller=misskey url=http://localhost:3001
  ```

  **`url=` も判別に使える**（2026-08-16 実走確認）。Mastodon が `localhost:3000`、
  Misskey が `localhost:3001`（pooza/chubo2#165 で `MISSKEY_PORT` の既定が 3001 になった）。
  ⚠ ただし**判定の主は `controller=` の側**のままにする。`url=` はポート設定に依存し、
  下記のとおり古い `.env` を持つ環境では両系とも 3000 を出すため。

**両ハーネスは同時に起動できる**（Mastodon 3000 / Misskey 3001、DB も 5433 / 5434 で非衝突。
2026-08-16 に同時稼働と両系実走を確認）。片方ずつ `teardown.sh` → `setup.sh` する必要は無くなった。

⚠ **既定の変更は `.env.example` にしか入っていない。**`.env` は gitignore されていて更新の導線が
無いため、**pooza/chubo2#165 より前に構築した環境は `MISSKEY_PORT=3000` のまま**で、従来どおり
衝突する。`grep MISSKEY_PORT .env` で確かめ、3000 なら `teardown.sh` → `setup.sh` で作り直す
（`.env` ごと消えて `.env.example` から作り直され、`.config/default.yml` の `url` も揃う。8〜9 分）。
⚠ **ポート衝突で proxy の起動に失敗した後は、`docker compose up -d` では復旧しない。**
ネットワーク未接続のコンテナが再利用され `host not found in upstream "web"` を繰り返すので、
`docker compose rm -sf proxy` で作り直す（pooza/chubo2#178）。

- 結果を記録するときは、この行もセットで残す（後から取り違えを検証できる）

判定基準:

- **Mastodon 系・Misskey 系の両方で `0 failures / 0 errors`。**片系だけでは不可
- **実走ごとの `TestHarness: controller=...` が、狙った系と一致している**
- 両系とも `develop` の同一 HEAD で走らせる
- omission は許容する（harness が構造的に提供しない範囲 = デーモン層・webhook・streaming・
  nodeinfo・seed 等を `harness?` で omit しているため）。ただし**件数が前回から大きく増えて
  いたら中身を見る**。無害な omit の増加と、前提が壊れて実行されなくなった退行は区別がつかない

**既知例外は無い。**両系とも 0 failures / 0 errors を実際に満たしている（#4492 を 2026-08-09 に
解消したため）。落ちたら例外を作らず原因を切り分ける。

参考値（2026-08-09 実測・両系とも同一 HEAD、クリーン再構築した harness）:

| 系 | 結果 |
| --- | --- |
| Mastodon（harness v4.6.5） | 1001 tests / 2007 assertions / **0 failures / 0 errors** / 152 omissions |
| Misskey（harness 2026.7.0） | 1004 tests / 2062 assertions / **0 failures / 0 errors** / 141 omissions |

⚠ **assertion 数は同一 HEAD でも数件ぶれる**（seed データ量に依存するテストがあるため）。
tests / failures / errors / omissions の 4 つで見る。

⚠ **Mastodon と Misskey で `harness?` omit の対象が違う**（Misskey harness は nginx を挟まない、
`access_token` 行を持たない等）。件数が両系で揃わないのは正常。

失敗が出たときの切り分け:

- **product の退行か、検証側の前提ズレか**を先に決める。2026-08-09 の 5 件（#4516 / #4552）は
  **5 件とも検証側**だった。「harness で落ちた = 本番が壊れている」ではない
- 疑わしいときは、**上流バージョンを 1 つ落として同一 HEAD でクリーン再構築**し、失敗集合が
  一致するかを見る（2026-08-09 の Mastodon v4.6.5 検証で使った手）。一致すれば上流起因ではない

記録先: [harness-verified-versions.yaml](../../../docs/harness-verified-versions.yaml)。上流バージョンの
`verified` 昇格を伴う実走は、この台帳に日付つきで残す。

## upstream の新しい版の検証

同期（`sync` スキルの §8）で、[harness-verified-versions.yaml](../../../docs/harness-verified-versions.yaml) の
`verified` より新しい stable、または Mastodon の新しい RC を見つけたときに回す。
時機は Mastodon RC＝約 1 週間の RC 期間中、Mastodon stable＝リリース直後、Misskey＝リリース後数日でデプロイ前。

upstream リリースの参照先（GitHub）:

- Mastodon: `mastodon/mastodon`（stable は `vX.Y.Z`、RC は `vX.Y.Z-rc.N`）
- Misskey: `misskey-dev/misskey`（stable は `YYYY.M.P`、alpha / beta は prerelease）。⚠ Docker Hub の `misskey/misskey` とは別

1. `cd ~/repos/chubo2/fedi-test-harness/<mastodon|misskey>`
2. `./scripts/update-version.sh` — upstream 最新に追従
3. `./scripts/reset.sh` — 新イメージ＋クリーン DB で再構築
4. モロヘイヤ側で harness テストを実走する（上の「リリースゲートとしての実走」と同じ作法。モロヘイヤ自前の Redis も harness が上げる）
5. 緑なら chubo2 の `.env.example` と `harness-verified-versions.yaml` の `verified` / `verified_at` を新しい版に更新する
