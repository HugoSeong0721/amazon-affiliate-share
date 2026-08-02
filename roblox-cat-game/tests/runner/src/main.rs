// luarun — Luau 스크립트를 실행하는 최소 런처.
//
// 로블록스 API 흉내는 전부 Luau 쪽(tests/mock/)에서 하고,
// 여기서는 파일을 읽고 원하는 환경(_ENV)으로 실행시켜주는 일만 한다.
//
//   cargo run --release -- tests/main.luau

use std::{fs, path::Path, process::ExitCode};
use mlua::{Lua, Value, Variadic};

fn main() -> ExitCode {
    let entry = match std::env::args().nth(1) {
        Some(path) => path,
        None => {
            eprintln!("usage: luarun <entry.luau>");
            return ExitCode::from(2);
        }
    };

    let lua = Lua::new();
    if let Err(err) = install_host_api(&lua, &entry) {
        eprintln!("호스트 API 설치 실패: {err}");
        return ExitCode::FAILURE;
    }

    let source = match fs::read_to_string(&entry) {
        Ok(text) => text,
        Err(err) => {
            eprintln!("{entry} 를 읽을 수 없습니다: {err}");
            return ExitCode::FAILURE;
        }
    };

    match lua.load(&source).set_name(&entry).exec() {
        Ok(()) => ExitCode::SUCCESS,
        Err(err) => {
            eprintln!("\n=== Luau 오류 ===\n{err}");
            ExitCode::FAILURE
        }
    }
}

fn install_host_api(lua: &Lua, entry: &str) -> mlua::Result<()> {
    let globals = lua.globals();

    let base = Path::new(entry)
        .parent()
        .map(|p| p.to_path_buf())
        .unwrap_or_default();
    globals.set("_scriptDir", base.to_string_lossy().to_string())?;

    // 파일 읽기
    globals.set(
        "_readFile",
        lua.create_function(|_, path: String| {
            fs::read_to_string(&path).map_err(|e| mlua::Error::runtime(format!("{path}: {e}")))
        })?,
    )?;

    // 지정한 환경 테이블로 청크를 컴파일해 함수로 돌려준다.
    // 게임 스크립트에 game/workspace/script 같은 가짜 전역을 심을 때 쓴다.
    globals.set(
        "_loadWithEnv",
        lua.create_function(|lua, (source, name, env): (String, String, mlua::Table)| {
            lua.load(&source)
                .set_name(&name)
                .set_environment(env)
                .into_function()
        })?,
    )?;

    // 기본 전역으로 청크를 컴파일 (Luau에는 loadstring이 없다)
    globals.set(
        "_loadChunk",
        lua.create_function(|lua, (source, name): (String, String)| {
            lua.load(&source).set_name(&name).into_function()
        })?,
    )?;

    // 테스트 출력은 stdout으로 바로 흘려보낸다
    globals.set(
        "_write",
        lua.create_function(|_, parts: Variadic<Value>| {
            let line: Vec<String> = parts
                .iter()
                .map(|v| match v {
                    Value::String(s) => s.to_string_lossy().to_string(),
                    other => format!("{other:?}"),
                })
                .collect();
            println!("{}", line.join(" "));
            Ok(())
        })?,
    )?;

    Ok(())
}
