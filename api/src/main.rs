use actix::Addr;
use actix_cors::Cors;
use actix_redis::{Command, RedisActor};
use actix_web::{web, App, HttpRequest, HttpResponse, HttpServer, Result};
use redis_async::resp::RespValue;
use redis_async::resp_array;
use serde::{Deserialize, Serialize};
use std::env;

type RedisCache = web::Data<Addr<RedisActor>>;

#[derive(Deserialize, Serialize)]
struct Item {
    key: String,
    value: String,
}

async fn store(redis: RedisCache, item: web::Json<Item>) -> Result<HttpResponse> {
    let redis_networking_result = redis
        .send(Command(resp_array!["SETNX", &item.key, &item.value]))
        .await;
    let redis_result = match redis_networking_result {
        Ok(redis_result) => redis_result,
        Err(e) => {
            return internal_error(format!("Redis unavailable. Error: {}", e));
        }
    };
    if let Err(e) = redis_result {
        return internal_error(format!(
            "Redis error occurred during SETNX operation. Error: {}",
            e
        ));
    }
    Ok(HttpResponse::Ok().json(Item {
        key: item.key.to_string(),
        value: item.value.to_string(),
    }))
}

async fn fetch(req: HttpRequest, redis: RedisCache) -> Result<HttpResponse> {
    let key = match req.match_info().get("key") {
        Some(key) => key,
        None => {
            return Ok(HttpResponse::BadRequest().body("key is required"));
        }
    };
    let redis_networking_result = redis.send(Command(resp_array!["GET", key])).await;
    let redis_result = match redis_networking_result {
        Ok(redis_result) => redis_result,
        Err(e) => {
            return internal_error(format!("Redis unavailable. Error: {}", e));
        }
    };
    let redis_resp_value = match redis_result {
        Ok(resp_value) => resp_value,
        Err(e) => {
            return internal_error(format!("Redis error occurred during GET operation: {}", e));
        }
    };
    let parsed_value_result = match redis_resp_value {
        RespValue::BulkString(bytes) => String::from_utf8(bytes),
        _ => {
            return Ok(HttpResponse::NotFound().body(""));
        }
    };
    let value = match parsed_value_result {
        Ok(value) => value,
        Err(e) => {
            return internal_error(format!("Value is not valid UTF-8 string. Error: {}", e));
        }
    };
    Ok(HttpResponse::Ok().json(Item {
        key: key.to_string(),
        value,
    }))
}

fn internal_error(error_message: String) -> Result<HttpResponse> {
    Ok(HttpResponse::InternalServerError().body(error_message))
}

#[actix_web::main]
async fn main() -> std::io::Result<()> {
    std::env::set_var("RUST_LOG", "actix_web=info,actix_redis=info");

    let redis_host = env::var("REDIS_HOST").unwrap_or("127.0.0.1:6379".to_string());

    HttpServer::new(move || {
        let cors = Cors::default()
            .allow_any_origin()
            .allowed_methods(vec!["GET", "POST"])
            .allow_any_header()
            .max_age(3600);

        App::new()
            .data(RedisActor::start(&redis_host))
            .wrap(cors)
            .service(web::resource("/").route(web::post().to(store)))
            .service(web::resource("/{key}").route(web::get().to(fetch)))
    })
    .bind("0.0.0.0:8080")?
    .run()
    .await
}
