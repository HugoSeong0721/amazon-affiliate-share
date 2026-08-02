# rbxlx2rbxl

XML place 파일(`.rbxlx`)을 Roblox 바이너리 place 파일(`.rbxl`)로 변환하는 작은 도구.

Roblox 공식 포맷 라이브러리(`rbx_xml` / `rbx_binary` — Rojo가 쓰는 것과 동일)를 그대로 사용한다.

```sh
cargo run --release -- input.rbxlx output.rbxl
```

보통은 직접 부르지 않고 `bash tools/build.sh` 가 알아서 호출한다.

## 왜 바이너리로 변환하나

GitHub raw 링크로 파일을 공유할 때 확장자에 따라 브라우저 동작이 달라진다.

| 확장자 | GitHub raw의 Content-Type | 브라우저 동작 |
|---|---|---|
| `.rbxlx` | `text/plain` | XML이 화면에 텍스트로 펼쳐짐 (우클릭 저장 필요) |
| `.rbxl` | `application/octet-stream` | 클릭하면 바로 다운로드 ✅ |

받는 사람에게 링크 하나만 보내야 한다면 `.rbxl` 쪽을 써야 한다.
