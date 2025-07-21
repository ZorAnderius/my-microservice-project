# Django Infrastructure with Terraform, Kubernetes & Helm

## Зміст

- [Опис структури проєкту](#опис-структури-проєкту)
- [Підготовка бекенду (S3 + DynamoDB)](#підготовка-бекенду-s3--dynamodb)
- [Запуск основної інфраструктури](#запуск-основної-інфраструктури)
- [Kubernetes та Helm](#kubernetes-та-helm)
- [Деплой Django-застосунку](#деплой-django-застосунку)
- [Очікування LoadBalancer та відкриття застосунку](#очікування-loadbalancer-та-відкриття-застосунку)
- [Видалення інфраструктури](#видалення-інфраструктури)

---

## Опис структури проєкту
Основна логіка відбувається в директорії lesson-8-9

```
lesson-8-9/
├── terraform/               # Проект Terraform з усіма конфігураціями інфраструктури
├── django_app/              # Застосунок Django з Dockerfile
├── charts/
│   └── django-app/          # Helm chart для Django застосунку
└── scripts/
    └── deploy.sh            # Скрипт розгортання (має бути запущений з terraform/)
```

---

###  Огляд інфрастуктури

Проєкт забезпечує наступне за допомогою Terraform:

- **S3 + DynamoDB** — Бекенд для стану та блокування Terraform
- **VPC** — з підмережами, маршрутизацією, доступом до Інтернету
- **EKS Cluster** — керований кластер Kubernetes
- **ECR** — реєстр контейнерів для образу Docker


### Архітектура проекту

```
[ Django Pod ]
     │
[ Kubernetes Service (LoadBalancer) ]
     │
[ AWS ELB (external DNS) ]
     │
[ Browser / curl ]
```

> Запити ззовні потрапляють на ELB, який перенаправляє на сервіс у кластері, що зв'язаний з Django-подом.


###  Підготовка для роботи

Для правильної роботи проект потребує декілька інструментів. Впевніться, що дані інструменти є встановлені

- `terraform`
- `kubectl`
- `awscli`
- `helm`
- `docker`

---


## Підготовка бекенду (S3 + DynamoDB)

```bash
cd lesson-8-9/terraform/modules/s3-backend
terraform init
terraform apply
```

> Це створить:
> - S3 bucket для зберігання terraform.tfstate
> - DynamoDB таблицю для блокування

---

## Запуск основної інфраструктури

Після створення бекенду:

```bash
cd ../..         # Повернення в директорію terraform
terraform init
terraform apply
```

> Це створить VPC, кластер EKS, репозиторій ECR тощо.

---

## Kubernetes та Helm

### Встановлення

Перед початком якщо дані інстурменти є відсутні то будт ласка встановіть їх:
- Встанови [kubectl](https://kubernetes.io/docs/tasks/tools/)
- Встанови [helm](https://helm.sh/docs/intro/install/)

---

Крім того важливою умовою є стоврення в папці **lesson-8-9** файлу **.env** з таким вмістом 

```bash
POSTGRES_HOST=postgresql.default.svc.cluster.local
POSTGRES_PORT=5432
POSTGRES_USER=django_user
POSTGRES_DB=django_db
POSTGRES_PASSWORD=pass9764gd
```

## Деплой Django-застосунку

Скрипт: `scripts/deploy.sh`


- Скрипт `deploy.sh` **повинен запускатися з папки `terraform`**, оскільки він працює з результатами, які створює Terraform, наприклад, отримує URL кластеру, ECR репозиторій та інші змінні середовища.


### Формат:

```bash
../scripts/deploy.sh <project-name> <dockerfile-path> <context-dir> <release-name> <helm-chart-path>
```

### Приклад:

```bash
../scripts/deploy.sh django-app ../django_app/Dockerfile ../django_app django-release ../charts/django-app
```

### Пояснення:

| Аргумент              | Опис                                                                 |
|-----------------------|----------------------------------------------------------------------|
| `django-app`          | Назва Docker образу та ECR репозиторію                              |
| `../django_app/Dockerfile` | Шлях до Dockerfile                                              |
| `../django_app`       | Контекст збірки Docker (звiдки копіюються файли)                    |
| `django-release`      | Назва Helm-релізу                                                    |
| `../charts/django-app`| Шлях до Helm-чарту                                                   |

---

## Очікування LoadBalancer та відкриття застосунку

>  Створення LoadBalancer у AWS може тривати **кілька хвилин** після деплою. Потрібно дочекатися, доки з'явиться зовнішній IP.

1. Перевір статус LoadBalancer:

```bash
kubectl get svc django-release -w
```

> Якщо `-w` не показує результат довго — натисни Ctrl+C і повтори через хвилину.

Знайди значення у колонці EXTERNAL-IP, наприклад:

```scss
NAME              TYPE           EXTERNAL-IP                                                                  PORT(S)
django-release    LoadBalancer   a18449ed0e0234cb1a897483b161b866-935326661.eu-central-1.elb.amazonaws.com   8000:...

```

2. Відкрий у браузері:

```
http://<external-dns>:8000
```

або:

```bash
curl http://<external-dns>:8000
```


3. Первірка DNS під час очікування LoadBalancer

Поки DNS не працює, можеш тимчасово зробити порт-форвардинг:

```bash
kubectl port-forward svc/django-release 8000:8000
```

І потім відкрий у браузері:


```bash
http://localhost:8000
```


Якщо це працює — значить, Django вже доступний, просто DNS ще не "дозрів".

---

## Видалення інфраструктури
Якщо потрібно видалити створені ресурси, то необхідно спочатку вручну знищити Helm-реліз (який створює LoadBalancer):

1. Перевір назву Helm-релізу (наприклад django-release):

```bash
helm list
```

2. Видали реліз:

  Якщо ви хочете видалити зразу всі реліз то використовуйте команду 

```bash
helm list --short | xargs -n1 helm uninstall 
```
> однак якщо немає ніяких релізів то буде викинута помилка



А якщо кожен окремо то:

```bash
helm uninstall django-release #назва того релізу який ви хочете видалити
```

та 

```bash
helm uninstall postgresql #назва того релізу який ви хочете видалити
```

3. Зачекати 2–5 хвилин, доки AWS знищить LoadBalancer (можна перевірити через kubectl get svc).

4. Коли всі сервіси з типом LoadBalancer зникли можна виконати:

```bash
terraform destroy
```

**Якщо спробувати видалити інфраструктуру до знищення LoadBalancer, Terraform завершиться з помилкою про залежності.**

---