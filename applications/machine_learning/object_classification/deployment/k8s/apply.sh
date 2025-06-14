#!/bin/bash
kubectl apply -f EfficientNetB0.yml
kubectl apply -f MobileNetV2.yml
kubectl apply -f ensemble.yml
kubectl apply -f preprocessing.yml
