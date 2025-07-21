# Django Infrastructure with Terraform, Kubernetes & Helm

## Зміст

- [Опис структури проєкту](#опис-структури-проєкту)
- [Підготовка бекенду (S3 + DynamoDB)](#підготовка-бекенду-s3--dynamodb)
- [Запуск основної інфраструктури](#запуск-основної-інфраструктури)
- [Kubernetes та Helm](#kubernetes-та-helm)
- [Деплой Django-застосунку](#деплой-django-застосунку)
- [Очікування LoadBalancer та відкриття застосунку](#очікування-loadbalancer-та-відкриття-застосунку)
- [Опис CI/CD архітектури](#опис-cicd-архітектури)
- [Робота CI/CD архітектури](#робота-cicd-архітектури)
- [Видалення інфраструктури](#видалення-інфраструктури)

---

## Опис структури проєкту
Основна логіка відбувається в директорії lesson-8-9

```sass
lesson-8-9/
├── terraform/                         # Основна директорія з Terraform конфігурацією
│   ├── main.tf                        # Підключення модулів (root-модуль)
│   ├── backend.tf                     # Налаштування бекенду Terraform (S3 + DynamoDB)
│   ├── outputs.tf                     # Загальні вихідні дані інфраструктури
│   └── modules/                       # Всі модулі інфраструктури
│       ├── s3-backend/               # Модуль для створення S3-бакета та DynamoDB таблиці
│       │   ├── s3.tf                 # Створення S3-бакета для Terraform state
│       │   ├── dynamodb.tf           # Створення DynamoDB для блокування Terraform
│       │   ├── variables.tf          # Змінні модуля
│       │   └── outputs.tf            # Виводи: імена ресурсів
│       │
│       ├── vpc/                      # Модуль для створення VPC
│       │   ├── vpc.tf                # Основна мережа, сабнети, Internet Gateway
│       │   ├── routes.tf             # Маршрутизація та маршрутні таблиці
│       │   ├── variables.tf          # Вхідні параметри для VPC
│       │   └── outputs.tf            # Виводи з модуля VPC
│       │
│       ├── ecr/                      # Модуль для створення ECR репозиторію
│       │   ├── ecr.tf                # Ресурс ECR
│       │   ├── variables.tf          # Змінні для ECR
│       │   └── outputs.tf            # URL репозиторію
│       │
│       ├── eks/                      # Модуль для створення Kubernetes (EKS) кластера
│       │   ├── eks.tf                # EKS кластер і worker-и
│       │   ├── aws_ebs_csi_driver.tf # Встановлення CSI драйвера для EBS
│       │   ├── variables.tf          # Змінні для кластера
│       │   └── outputs.tf            # Інформація про кластер (ім’я, endpoint, kubeconfig)
│       │
│       ├── jenkins/                  # Модуль для розгортання Jenkins через Helm
│       │   ├── jenkins.tf            # Helm release для Jenkins
│       │   ├── variables.tf          # Параметри чарта, namespace, ресурси
│       │   ├── providers.tf          # Kubernetes та Helm провайдери
│       │   ├── values.yaml           # Конфігурація Jenkins (ресурси, доступ)
│       │   └── outputs.tf            # Вивід: адреса Jenkins, токен
│       │
│       └── argo_cd/                  # Модуль для розгортання Argo CD через Helm
│           ├── argo_cd.tf            # Helm release для Argo CD (раніше jenkins.tf)
│           ├── variables.tf          # Параметри чарта Argo CD
│           ├── providers.tf          # Провайдери для Kubernetes/Helm
│           ├── values.yaml           # Конфігурація Argo CD
│           ├── outputs.tf            # Вивід: hostname, пароль адміністратора
│           └── charts/               # Helm-чарт для створення ArgoCD applications
│               ├── Chart.yaml        # Мета-інформація про чарт
│               ├── values.yaml       # Список застосунків та репозиторіїв
│               └── templates/
│                   ├── application.yaml   # Арго застосунок (App)
│                   └── repository.yaml    # Git-репозиторій для Argo CD
│
├── django_app/                     # Django застосунок з Dockerfile
│   └── Dockerfile                  # Dockerfile для створення образу застосунку
│
├── charts/                         # Helm-чарти для мікросервісів, не пов’язані з модулями
│   └── django-app/                 # Helm-чарт для Django застосунку
│       ├── Chart.yaml              # Опис чарта
│       ├── values.yaml             # Змінні середовища (env)
│       └── templates/              # Kubernetes-ресурси
│           ├── deployment.yaml     # Деплоймент Django
│           ├── service.yaml        # Сервіс для доступу
│           ├── configmap.yaml      # Конфігурація Django
│           └── hpa.yaml            # Horizontal Pod Autoscaler
│
└── scripts/                        # Bash-скрипти для роботи з проєктом
    └── delete-all-resources.sh    # Скрипт автоматичного видалення Jenkins і всієї інфраструктури

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


## Опис CI/CD архітектури
```sass
              GitHub (код і Helm chart)
                     ▲
                     │
     ┌───────────────┴───────────────┐
     │         Continuous            │
     │         Integration           │
     │           Jenkins             │
     │  (запускається через Helm)    │
     │      │                ▲       │
     │      ▼                │       │
     │  1. Збірка Docker-образу      │
     │  2. Push до Amazon ECR        │
     │  3. Зміна values.yaml         │
     │  4. Push у GitHub (main)      │
     └───────────────┬───────────────┘
                     │
                     ▼
         ┌──────────────────────────┐
         │       Continuous         │
         │        Delivery          │
         │         Argo CD          │
         │   (встановлено Helm+TF)  │
         └───────────┬──────────────┘
                     │
                     ▼
            Kubernetes кластер (EKS)

```

## Робота CI/CD архітектури

Уявімо, що ваша команда працює над Django-застосунком. Код пишеться локально, тестується, і коли він готовий — розробник пушить зміни до репозиторію на **GitHub**. Саме з цього моменту і запускається весь автоматизований процес.

Все починається з **GitHub**, який відіграє роль центрального місця зберігання не лише коду, а й конфігурацій для деплою. У репозиторії зберігаються два ключові елементи: сам код **Django** і **Helm-чарт**, який описує, як цей код буде розгорнуто у **Kubernetes**. Тобто, **Helm-чарт** — це «інструкція», за якою Kubernetes зрозуміє, що і як запускати.

Коли код потрапляє у main-гілку, у гру вступає **Jenkins** — наша система безперервної інтеграції **(CI)**. Він автоматично активується після змін у репозиторії. Але **Jenkins** не просто запускається — він розгорнутий у **Kubernetes**-кластері через **Helm**, а сама його інсталяція автоматизована **Terraform**-скриптами. Тобто **Jenkins** — повністю частина нашої інфраструктури як коду.

**Jenkins** бере нову версію коду та запускає **Jenkins pipeline** — це набір автоматизованих кроків, які виконуються послідовно. Спочатку, за допомогою **Kaniko** (інструмент для безпечної збірки **Docker**-образів без потреби в root-доступі), він створює новий **Docker**-образ **Django**-застосунку. Далі цей образ відправляється в **Amazon ECR** — приватний контейнерний реєстр у хмарі AWS, де зберігаються всі наші зібрані образи.

Але на цьому **Jenkins** не зупиняється. Щоб **Kubernetes** знав, що з’явився новий образ, **Jenkins** автоматично відкриває **Helm**-чарт, знаходить у ньому файл **values.yaml** і оновлює тег образу (наприклад, image.tag: v23 замість v22). Після цього **Jenkins** комітить і пушить цю зміну назад у репозиторій на **GitHub**. Тобто **Helm**-чарт оновлено — Git знає, що треба деплоїти нову версію.

І ось тут вмикається **Argo CD** — система безперервної доставки **(CD)**, яка також встановлена через **Helm** і **Terraform**. **Argo CD** працює за принципом **GitOps** — він не чекає ручних команд, а постійно стежить за Git-репозиторієм. Щойно він бачить, що файл values.yaml змінився — значить, вийшла нова версія застосунку. **Argo CD** автоматично запускає оновлення, не потребуючи жодної дії з боку розробника.

На цьому етапі **Kubernetes**-кластер, створений через **Terraform** в **Amazon EKS**, отримує нову конфігурацію **Helm**. **Kubernetes** оновлює відповідний **Helm**-реліз, зупиняє старі **Pod**-и, і запускає нові, вже з новим **Docker**-образом, який нещодавно зібрав **Jenkins**.

У результаті — нова версія **Django**-застосунку вже працює в кластері. Але як користувач потрапляє на сайт?

Тут усе просто. **Kubernetes** створює сервіс типу **LoadBalancer**, який автоматично підключається до зовнішнього **AWS Load Balancer (ELB)**. Цей балансувальник отримує публічний **DNS** (наприклад, my-app-123456.elb.amazonaws.com), і коли користувач відкриває цю адресу у браузері, запит проходить такий шлях:

```sass
Користувач → AWS ELB → Kubernetes Service → Django Pod
```

Запит надходить іззовні, переходить через балансувальник до сервісу **Kubernetes**, а далі вже передається безпосередньо у **Pod** із вашим **Django**-застосунком.

---

**Що відбувається після кожного оновлення**

Уся система працює як замкнене коло:

- Ви пушите нову версію коду.

- Jenkins автоматично збирає Docker-образ.

- Jenkins оновлює Helm chart і пушить зміну.

- Argo CD бачить цю зміну та деплоїть нову версію.

- Kubernetes оновлює застосунок у кластері.

- Користувач бачить результат без жодної затримки або ручного втручання.



## Видалення інфраструктури
Якщо потрібно видалити створені ресурси, то необхідно спочатку вручну знищити Helm-реліз (який створює LoadBalancer):

1. Перевір назву Helm-релізу (наприклад django-release):

```bash
helm list
```

2. Видали реліз:


### За допомогою скрипта

Для видалення всіх встановлених ресурсів рекомендується з папки **scripts**

```bash
cd "$(git rev-parse --show-toplevel)"
cd lesson-8-9/scripts
```

запустити скрипт

```bash
./delete-all-recourses.sh
```

### Ручне видалення

Для уникнення помилока при видаленні  перш за все потрібно видалити Jankins:

Jankins

```bash
helm uninstall jenkins -n jenkins
```

потім


```bash
kubectl delete pvc --all -n jenkins
```

та

```bash
kubectl delete namespace jenkins
```

а потім з папки **terraform** 
```bash
cd "$(git rev-parse --show-toplevel)"
cd lesson-8-9/terraform
```

виконати наступну команду

```bash
terraform destroy
```

і на останок перейти в папку **s3-backend**
```bash
cd "$(git rev-parse --show-toplevel)"
cd lesson-8-9/terraform/modules/s3-backend
```
та виконати 

```bash
terraform destroy
```

для знищення s3 bucket та dynamoDB.
---