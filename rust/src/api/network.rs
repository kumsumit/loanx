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

#[derive(Debug)]
#[flutter_rust_bridge::frb]
pub struct OtpChallenge {
    pub success: bool,
    pub challenge_id: String,
    pub expires_in_seconds: u32,
    pub error_message: Option<String>,
}
#[derive(Debug)]
#[flutter_rust_bridge::frb]
pub struct AuthTokens {
    pub success: bool,
    pub access_token: String,
    pub refresh_token: String,
    pub user_id: String,
    pub error_message: Option<String>,
}
#[derive(Debug)]
#[flutter_rust_bridge::frb]
pub struct NetworkResult {
    pub success: bool,
    pub error_message: Option<String>,
}

#[derive(Debug)]
#[flutter_rust_bridge::frb]
pub struct ChatCredentials {
    pub success: bool,
    pub jid: String,
    pub access_token: String,
    pub expires_at_ms: i64,
    pub websocket_url: String,
    pub error_message: Option<String>,
}

#[flutter_rust_bridge::frb]
pub async fn request_chat_credentials(
    server_address: String,
    server_name: String,
    trusted_certificate_pem: String,
    device_id: String,
    access_token: String,
) -> ChatCredentials {
    match send_request(
        &server_address,
        &server_name,
        &trusted_certificate_pem,
        &device_id,
        access_token,
        v1::request::Payload::ChatToken(v1::ChatTokenRequest {}),
    )
    .await
    {
        Ok(v1::response::Result::ChatToken(v)) => ChatCredentials {
            success: true,
            jid: v.jid,
            access_token: v.access_token,
            expires_at_ms: v.expires_at_ms,
            websocket_url: v.websocket_url,
            error_message: None,
        },
        Ok(v1::response::Result::Error(v)) => ChatCredentials {
            success: false,
            jid: String::new(),
            access_token: String::new(),
            expires_at_ms: 0,
            websocket_url: String::new(),
            error_message: Some(v.message),
        },
        Ok(_) => ChatCredentials {
            success: false,
            jid: String::new(),
            access_token: String::new(),
            expires_at_ms: 0,
            websocket_url: String::new(),
            error_message: Some("unexpected server response".into()),
        },
        Err(e) => ChatCredentials {
            success: false,
            jid: String::new(),
            access_token: String::new(),
            expires_at_ms: 0,
            websocket_url: String::new(),
            error_message: Some(e.to_string()),
        },
    }
}

#[flutter_rust_bridge::frb]
pub async fn request_otp(
    server_address: String,
    server_name: String,
    trusted_certificate_pem: String,
    device_id: String,
    phone_e164: String,
) -> OtpChallenge {
    match send_request(
        &server_address,
        &server_name,
        &trusted_certificate_pem,
        &device_id,
        String::new(),
        v1::request::Payload::RequestOtp(v1::RequestOtpRequest { phone_e164 }),
    )
    .await
    {
        Ok(v1::response::Result::RequestOtp(v)) => OtpChallenge {
            success: true,
            challenge_id: v.challenge_id,
            expires_in_seconds: v.expires_in_seconds,
            error_message: None,
        },
        Ok(v1::response::Result::Error(v)) => OtpChallenge {
            success: false,
            challenge_id: String::new(),
            expires_in_seconds: 0,
            error_message: Some(v.message),
        },
        Ok(_) => OtpChallenge {
            success: false,
            challenge_id: String::new(),
            expires_in_seconds: 0,
            error_message: Some("unexpected server response".into()),
        },
        Err(e) => OtpChallenge {
            success: false,
            challenge_id: String::new(),
            expires_in_seconds: 0,
            error_message: Some(e.to_string()),
        },
    }
}

#[flutter_rust_bridge::frb]
pub async fn verify_otp(
    server_address: String,
    server_name: String,
    trusted_certificate_pem: String,
    device_id: String,
    challenge_id: String,
    phone_e164: String,
    otp: String,
    preferred_language: String,
) -> AuthTokens {
    match send_request(
        &server_address,
        &server_name,
        &trusted_certificate_pem,
        &device_id,
        String::new(),
        v1::request::Payload::VerifyOtp(v1::VerifyOtpRequest {
            challenge_id,
            phone_e164,
            otp,
            preferred_language,
        }),
    )
    .await
    {
        Ok(v1::response::Result::VerifyOtp(v)) => AuthTokens {
            success: true,
            access_token: v.access_token,
            refresh_token: v.refresh_token,
            user_id: v.user_id,
            error_message: None,
        },
        Ok(v1::response::Result::Error(v)) => AuthTokens {
            success: false,
            access_token: String::new(),
            refresh_token: String::new(),
            user_id: String::new(),
            error_message: Some(v.message),
        },
        Ok(_) => AuthTokens {
            success: false,
            access_token: String::new(),
            refresh_token: String::new(),
            user_id: String::new(),
            error_message: Some("unexpected server response".into()),
        },
        Err(e) => AuthTokens {
            success: false,
            access_token: String::new(),
            refresh_token: String::new(),
            user_id: String::new(),
            error_message: Some(e.to_string()),
        },
    }
}

#[flutter_rust_bridge::frb]
pub async fn update_language(
    server_address: String,
    server_name: String,
    trusted_certificate_pem: String,
    device_id: String,
    access_token: String,
    preferred_language: String,
) -> NetworkResult {
    match send_request(
        &server_address,
        &server_name,
        &trusted_certificate_pem,
        &device_id,
        access_token,
        v1::request::Payload::UpdateLanguage(v1::UpdateLanguageRequest { preferred_language }),
    )
    .await
    {
        Ok(v1::response::Result::UpdateLanguage(_)) => NetworkResult {
            success: true,
            error_message: None,
        },
        Ok(v1::response::Result::Error(v)) => NetworkResult {
            success: false,
            error_message: Some(v.message),
        },
        Ok(_) => NetworkResult {
            success: false,
            error_message: Some("unexpected server response".into()),
        },
        Err(e) => NetworkResult {
            success: false,
            error_message: Some(e.to_string()),
        },
    }
}

#[flutter_rust_bridge::frb]
pub async fn refresh_session(
    server_address: String,
    server_name: String,
    trusted_certificate_pem: String,
    device_id: String,
    refresh_token: String,
) -> AuthTokens {
    match send_request(
        &server_address,
        &server_name,
        &trusted_certificate_pem,
        &device_id,
        String::new(),
        v1::request::Payload::RefreshToken(v1::RefreshTokenRequest { refresh_token }),
    )
    .await
    {
        Ok(v1::response::Result::RefreshToken(v)) => AuthTokens {
            success: true,
            access_token: v.access_token,
            refresh_token: v.refresh_token,
            user_id: String::new(),
            error_message: None,
        },
        Ok(v1::response::Result::Error(v)) => AuthTokens {
            success: false,
            access_token: String::new(),
            refresh_token: String::new(),
            user_id: String::new(),
            error_message: Some(v.message),
        },
        Ok(_) => AuthTokens {
            success: false,
            access_token: String::new(),
            refresh_token: String::new(),
            user_id: String::new(),
            error_message: Some("unexpected server response".into()),
        },
        Err(e) => AuthTokens {
            success: false,
            access_token: String::new(),
            refresh_token: String::new(),
            user_id: String::new(),
            error_message: Some(e.to_string()),
        },
    }
}

async fn send_request(
    address: &str,
    name: &str,
    certificate: &str,
    device: &str,
    token: String,
    payload: v1::request::Payload,
) -> anyhow::Result<v1::response::Result> {
    let client = Client::builder()
        .with_tls(certificate)
        .map_err(|e| anyhow!(e.to_string()))?
        .with_io("0.0.0.0:0")
        .map_err(|e| anyhow!(e.to_string()))?
        .start()
        .map_err(|e| anyhow!(e.to_string()))?;
    let mut connection = client
        .connect(Connect::new(resolve_address(address)?).with_server_name(name))
        .await?;
    let mut stream = connection.open_bidirectional_stream().await?;
    let mut id = vec![0u8; 16];
    rand::rng().fill_bytes(&mut id);
    let request = v1::Request {
        protocol_major: PROTOCOL_MAJOR,
        request_id: id.clone(),
        device_id: device.into(),
        access_token: token,
        payload: Some(payload),
    };
    write_frame(&mut stream, &request.encode_to_vec()).await?;
    stream.shutdown().await?;
    let response = v1::Response::decode(read_frame(&mut stream).await?.as_slice())?;
    if response.request_id != id {
        return Err(anyhow!("server response request_id mismatch"));
    }
    response.result.context("server response missing result")
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
