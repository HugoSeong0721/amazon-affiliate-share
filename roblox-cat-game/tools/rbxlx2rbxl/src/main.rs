use std::{env, fs::File, io::{BufReader, BufWriter}};

fn main() -> Result<(), Box<dyn std::error::Error>> {
    let args: Vec<String> = env::args().collect();
    if args.len() != 3 {
        eprintln!("usage: rbxlx2rbxl <input.rbxlx> <output.rbxl>");
        std::process::exit(2);
    }
    let dom = rbx_xml::from_reader_default(BufReader::new(File::open(&args[1])?))?;
    let roots: Vec<_> = dom.root().children().to_vec();
    rbx_binary::to_writer(BufWriter::new(File::create(&args[2])?), &dom, &roots)?;
    println!("wrote {}", args[2]);
    Ok(())
}
