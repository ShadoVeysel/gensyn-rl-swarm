## 🌐 **Gensyn `swarm.pem` Dosyasını İndirme**

Komutu kopyala ve terminale yapıştır.
```bash
cd rl-swarm
[ -f swarmdownloud.sh ] && rm swarmdownloud.sh;
curl -sSL https://raw.githubusercontent.com/ShadoVeysel/gensyn-rl-swarm/main/swarmdownloud.sh -o swarmdownloud.sh && chmod +x swarmdownloud.sh && ./swarmdownloud.sh
````
Size bir link oluşturur, bu linki PC browserında açtığınızda otomatik olarak swarm.pem'i indirir.
