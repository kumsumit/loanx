use std::net::{SocketAddr, ToSocketAddrs};

use anyhow::{anyhow, Context};
use prost::Message;
use rand::Rng;
use s2n_quic::{client::Connect, Client};
use tokio::io::{AsyncReadExt, AsyncWriteExt};

use crate::protocol::{v1, MAX_FRAME_BYTES, PROTOCOL_MAJOR};

#[derive(Debug)]
#[flutter_rust_bridge::frb]
pub struct ServerHello {
    pub success: bool,
    pub protocol_major: u32,
    pub server_build: String,
    pub maximum_frame_bytes: u32,
    pub capabilities: Vec<String>,
    pub error_message: Option<String>,
}

/// Negotiates the LoanX protocol through Rust so Flutter never owns QUIC or
/// Protobuf transport details. `trusted_certificate_pem` must authenticate
/// `server_name`; certificate validation is never disabled.
#[flutter_rust_bridge::frb]
pub async fn connect_and_hello(
    server_address: String,
    server_name: String,
    trusted_certificate_pem: String,
    device_id: String,
    client_build: String,
) -> ServerHello {
    match connect_and_hello_inner(
        server_address,
        server_name,
        trusted_certificate_pem,
        device_id,
        client_build,
    )
    .await
    {
        Ok(value) => value,
        Err(cause) => ServerHello {
            success: false,
            protocol_major: 0,
            server_build: String::new(),
            maximum_frame_bytes: 0,
            capabilities: Vec::new(),
            error_message: Some(cause.to_string()),
        },
    }
}

async fn connect_and_hello_inner(
    server_address: String,
    server_name: String,
    trusted_certificate_pem: String,
    device_id: String,
    client_build: String,
) -> anyhow::Result<ServerHello> {
    let address = resolve_address(&server_address)?;
    let client = Client::builder()
        .with_tls(trusted_certificate_pem.as_str())
        .map_err(|cause| anyhow!(cause.to_string()))?
        .with_io("0.0.0.0:0")
        .map_err(|cause| anyhow!(cause.to_string()))?
        .start()
        .map_err(|cause| anyhow!(cause.to_string()))?;
    let connect = Connect::new(address).with_server_name(server_name);
    let mut connection = client
        .connect(connect)
        .await
        .context("connect to LoanX server")?;
    let mut stream = connection
        .open_bidirectional_stream()
        .await
        .context("open request stream")?;

    let mut request_id = vec![0_u8; 16];
    rand::rng().fill_bytes(&mut request_id);
    let request = v1::Request {
        protocol_major: PROTOCOL_MAJOR,
        request_id: request_id.clone(),
        device_id,
        access_token: String::new(),
        payload: Some(v1::request::Payload::Hello(v1::HelloRequest {
            minimum_protocol_major: PROTOCOL_MAJOR,
            maximum_protocol_major: PROTOCOL_MAJOR,
            client_build,
            capabilities: vec!["ping".into()],
        })),
    };
    write_frame(&mut stream, &request.encode_to_vec()).await?;
    stream.shutdown().await.context("finish request")?;
    let bytes = read_frame(&mut stream).await?;
    let response = v1::Response::decode(bytes.as_slice()).context("decode server response")?;
    if response.request_id != request_id {
        return Err(anyhow!("server response request_id mismatch"));
    }
    if response.protocol_major != PROTOCOL_MAJOR {
        return Err(anyhow!("server selected an incompatible protocol major"));
    }

    match response.result {
        Some(v1::response::Result::Hello(value)) => Ok(ServerHello {
            success: true,
            protocol_major: value.selected_protocol_major,
            server_build: value.server_build,
            maximum_frame_bytes: value.maximum_frame_bytes,
            capabilities: value.capabilities,
            error_message: None,
        }),
        Some(v1::response::Result::Error(value)) => Err(anyhow!(
            "server protocol error {}: {}",
            value.code,
            value.message
        )),
        _ => Err(anyhow!("server returned an unexpected response payload")),
    }
}

fn resolve_address(value: &str) -> anyhow::Result<SocketAddr> {
    value
        .to_socket_addrs()
        .with_context(|| format!("resolve server address {value}"))?
        .next()
        .ok_or_else(|| anyhow!("server_address did not resolve"))
}
async fn write_frame(
    stream: &mut s2n_quic::stream::BidirectionalStream,
    frame: &[u8],
) -> anyhow::Result<()> {
    if frame.is_empty() || frame.len() > MAX_FRAME_BYTES {
        return Err(anyhow!("request frame is outside the allowed range"));
    }
    stream
        .write_u32(frame.len() as u32)
        .await
        .context("write request frame length")?;
    stream.write_all(frame).await.context("write request frame")
}
async fn read_frame(stream: &mut s2n_quic::stream::BidirectionalStream) -> anyhow::Result<Vec<u8>> {
    let length = stream
        .read_u32()
        .await
        .context("read response frame length")? as usize;
    if length == 0 || length > MAX_FRAME_BYTES {
        return Err(anyhow!("response frame is outside the allowed range"));
    }
    let mut bytes = vec![0; length];
    stream
        .read_exact(&mut bytes)
        .await
        .context("read response frame")?;
    Ok(bytes)
}
#[cfg(test)]
mod tests {
    use super::*;
    #[test]
    fn rejects_unresolvable_address() {
        assert!(resolve_address("not an address").is_err());
    }
}
